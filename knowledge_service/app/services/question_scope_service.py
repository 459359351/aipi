"""
题目公司作用域服务。
"""

from __future__ import annotations

from typing import Optional

from fastapi import HTTPException
from sqlalchemy import select
from sqlalchemy.orm import Session

from ..models.question import Essay, Judge, MultipleChoice, SingleChoice
from ..models.question_company_scope_rel import QuestionCompanyScopeRel
from ..security.company_scope import CompanyScope, apply_question_scope, validate_target_company_ids

QUESTION_MODEL_MAP = {
    "single": SingleChoice,
    "multiple": MultipleChoice,
    "judge": Judge,
    "essay": Essay,
}


def get_visible_question(
    db: Session,
    scope: CompanyScope,
    question_type: str,
    question_id: int,
):
    model = QUESTION_MODEL_MAP[question_type]
    query = db.query(model).filter(model.id == question_id)
    query = apply_question_scope(query, scope, question_type, model)
    return query.first()


def get_question_company_ids(
    db: Session,
    question_type: str,
    question_id: int,
) -> list[str]:
    rows = db.execute(
        select(QuestionCompanyScopeRel.company_id)
        .where(
            QuestionCompanyScopeRel.question_type == question_type,
            QuestionCompanyScopeRel.question_id == question_id,
        )
        .order_by(QuestionCompanyScopeRel.company_id)
    ).all()
    return [str(row[0]) for row in rows]


def replace_orphan_question_company_scopes(
    db: Session,
    question_type: str,
    question_id: int,
    company_ids: list[str],
) -> None:
    db.query(QuestionCompanyScopeRel).filter(
        QuestionCompanyScopeRel.question_type == question_type,
        QuestionCompanyScopeRel.question_id == question_id,
    ).delete(synchronize_session=False)
    for company_id in company_ids:
        db.add(
            QuestionCompanyScopeRel(
                question_type=question_type,
                question_id=question_id,
                company_id=company_id,
            )
        )


def update_question_company_scopes_if_needed(
    db: Session,
    scope: CompanyScope,
    question_type: str,
    question_obj,
    target_company_ids,
) -> Optional[list[str]]:
    if target_company_ids is None:
        return None
    if getattr(question_obj, "document_id", None):
        raise HTTPException(
            status_code=400,
            detail="文档派生题目的权限归属必须继承文档，不能单独修改 target_company_ids",
        )
    company_ids = validate_target_company_ids(scope, target_company_ids, required=True)
    replace_orphan_question_company_scopes(db, question_type, int(question_obj.id), company_ids)
    return company_ids
