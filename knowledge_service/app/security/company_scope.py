"""
公司作用域权限契约与查询 helper。
"""

from __future__ import annotations

import json
from dataclasses import dataclass
from typing import Any, Iterable, Optional

from fastapi import HTTPException, Query
from sqlalchemy import and_, or_, select, true

from ..models.document import Document
from ..models.document_company_scope_rel import DocumentCompanyScopeRel
from ..models.question_company_scope_rel import QuestionCompanyScopeRel

GLOBAL_ADMIN_ROLE = "global_admin"
BRANCH_ADMIN_ROLE = "branch_admin"
QUESTION_TYPES = {"single", "multiple", "judge", "essay"}

_GLOBAL_ROLE_ALIASES = {"global_admin", "global", "headquarters_admin", "hq_admin"}
_BRANCH_ROLE_ALIASES = {"branch_admin", "branch", "company_admin", "subsidiary_admin"}


@dataclass(frozen=True)
class CompanyScope:
    role: str
    company_id: str

    @property
    def is_global_admin(self) -> bool:
        return self.role == GLOBAL_ADMIN_ROLE

    @property
    def is_branch_admin(self) -> bool:
        return self.role == BRANCH_ADMIN_ROLE


def normalize_scope_role(role: str) -> str:
    value = str(role or "").strip().lower()
    if value in _GLOBAL_ROLE_ALIASES:
        return GLOBAL_ADMIN_ROLE
    if value in _BRANCH_ROLE_ALIASES:
        return BRANCH_ADMIN_ROLE
    raise HTTPException(status_code=400, detail="scope_role 必须是 global_admin 或 branch_admin")


def get_company_scope(
    scope_role: str = Query(..., description="调用方权限角色：global_admin / branch_admin"),
    scope_company_id: str = Query(..., description="调用方所属公司/分公司 ID"),
) -> CompanyScope:
    normalized_role = normalize_scope_role(scope_role)
    company_id = str(scope_company_id or "").strip()
    if not company_id:
        raise HTTPException(status_code=400, detail="scope_company_id 不能为空")
    return CompanyScope(role=normalized_role, company_id=company_id)


def normalize_company_ids(raw_value: Any) -> list[str]:
    if raw_value is None:
        return []
    if isinstance(raw_value, str):
        text = raw_value.strip()
        if not text:
            return []
        if text.startswith("["):
            try:
                parsed = json.loads(text)
            except json.JSONDecodeError as exc:
                raise HTTPException(status_code=400, detail="target_company_ids 必须是合法 JSON 数组") from exc
            if not isinstance(parsed, list):
                raise HTTPException(status_code=400, detail="target_company_ids 必须是字符串数组")
            items = parsed
        else:
            items = [part.strip() for part in text.split(",")]
    elif isinstance(raw_value, Iterable):
        items = list(raw_value)
    else:
        raise HTTPException(status_code=400, detail="target_company_ids 必须是字符串数组")

    normalized: list[str] = []
    seen: set[str] = set()
    for item in items:
        value = str(item or "").strip()
        if not value or value in seen:
            continue
        seen.add(value)
        normalized.append(value)
    return normalized


def validate_target_company_ids(
    scope: CompanyScope,
    raw_value: Any,
    *,
    required: bool,
) -> Optional[list[str]]:
    if raw_value is None:
        if required:
            raise HTTPException(status_code=400, detail="target_company_ids 必填且不能为空")
        return None

    company_ids = normalize_company_ids(raw_value)
    if not company_ids:
        raise HTTPException(status_code=400, detail="target_company_ids 必填且不能为空")

    if scope.is_branch_admin and company_ids != [scope.company_id]:
        raise HTTPException(
            status_code=403,
            detail="分公司管理员只能绑定自己所属的 company_id",
        )
    return company_ids


def apply_document_scope(query, scope: CompanyScope, document_id_col=Document.id):
    if scope.is_global_admin:
        return query
    return query.filter(
        select(DocumentCompanyScopeRel.id)
        .where(
            DocumentCompanyScopeRel.document_id == document_id_col,
            DocumentCompanyScopeRel.company_id == scope.company_id,
        )
        .exists()
    )


def build_document_scope_clause(scope: CompanyScope, document_id_col):
    if scope.is_global_admin:
        return true()
    return (
        select(DocumentCompanyScopeRel.id)
        .where(
            DocumentCompanyScopeRel.document_id == document_id_col,
            DocumentCompanyScopeRel.company_id == scope.company_id,
        )
        .exists()
    )


def apply_question_scope(query, scope: CompanyScope, question_type: str, model):
    return query.filter(
        build_question_scope_clause(
            scope=scope,
            question_type=question_type,
            question_id_col=model.id,
            document_id_col=model.document_id,
        )
    )


def build_question_scope_clause(
    scope: CompanyScope,
    question_type: str,
    question_id_col,
    document_id_col,
):
    normalized_q_type = str(question_type or "").strip().lower()
    if normalized_q_type not in QUESTION_TYPES:
        raise HTTPException(status_code=400, detail="question_type 必须是 single/multiple/judge/essay")
    if scope.is_global_admin:
        return true()

    document_visible = and_(
        document_id_col.is_not(None),
        build_document_scope_clause(scope, document_id_col),
    )
    orphan_visible = and_(
        document_id_col.is_(None),
        select(QuestionCompanyScopeRel.id)
        .where(
            QuestionCompanyScopeRel.question_type == normalized_q_type,
            QuestionCompanyScopeRel.question_id == question_id_col,
            QuestionCompanyScopeRel.company_id == scope.company_id,
        )
        .exists(),
    )
    return or_(document_visible, orphan_visible)
