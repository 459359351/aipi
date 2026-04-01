"""
考核批次 & 题库 API —— 提供批次列表和题库列表供前端下拉选择
"""

from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session

from ..database import get_db
from ..models.assessment_batch import AssessmentBatch

router = APIRouter(tags=["考核批次"])


@router.get("/assessment-batches", summary="获取考核批次列表")
async def list_assessment_batches(db: Session = Depends(get_db)):
    """返回 active/completed 状态的考核批次，按创建时间倒序"""
    batches = (
        db.query(AssessmentBatch)
        .filter(AssessmentBatch.status.in_(["active", "completed"]))
        .order_by(AssessmentBatch.created_at.desc())
        .all()
    )
    return [
        {
            "id": b.id,
            "batch_name": b.batch_name,
            "title": b.title,
            "assessment_type": b.assessment_type,
            "status": b.status,
            "bank_id_range": b.bank_id_range,
        }
        for b in batches
    ]


@router.get("/banks", summary="获取题库列表")
async def list_banks(db: Session = Depends(get_db)):
    """返回所有题库，供"按错题"Tab 的题库下拉选择"""
    from sqlalchemy import text
    rows = db.execute(text("SELECT id, bank_name FROM tb_banks ORDER BY id")).all()
    return [{"id": r[0], "bank_name": r[1]} for r in rows]
