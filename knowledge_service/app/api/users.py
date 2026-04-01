"""
用户 API —— 提供用户列表供前端下拉选择
"""

from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session

from ..database import get_db
from ..models.user import User

router = APIRouter(prefix="/users", tags=["用户"])


@router.get("", summary="获取用户列表")
async def list_users(db: Session = Depends(get_db)):
    """返回所有用户的 id 和 name"""
    users = (
        db.query(User)
        .order_by(User.id)
        .all()
    )
    return [
        {
            "id": u.id,
            "name": u.name,
            "username": u.username,
        }
        for u in users
    ]
