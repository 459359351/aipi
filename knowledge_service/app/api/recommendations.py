"""
题目推荐 API —— 按文档练习 / 按错题推荐、人工题知识点关联
"""

import json
from fastapi import APIRouter, Depends, HTTPException, Query
import time
from sqlalchemy.orm import Session

from ..database import get_db
from ..schemas.recommendation import (
    ByDocumentRecommendationResponse,
    ByQuestionRecommendationResponse,
)
from ..services.recommendation_service import (
    build_manual_question_knowledge_rel,
    recommend_by_profile,
    recommend_by_document,
    recommend_by_question,
)
from ..models.user_question_behavior import UserQuestionBehavior
from ..models.user_profile import UserProfile

router = APIRouter(prefix="/recommendations", tags=["题目推荐"])


# #region agent log
def _debug_log(location: str, message: str, data: dict, hypothesis_id: str):
    try:
        with open("/Users/zhangjingjun/Downloads/zhijia/AIPI/.cursor/debug-abf3c5.log", "a", encoding="utf-8") as f:
            f.write(json.dumps({
                "sessionId": "abf3c5",
                "runId": "run1",
                "hypothesisId": hypothesis_id,
                "location": location,
                "message": message,
                "data": data,
                "timestamp": int(time.time() * 1000),
            }, ensure_ascii=False) + "\n")
    except Exception:
        pass
# #endregion


@router.get(
    "/by-document/{document_id}",
    response_model=ByDocumentRecommendationResponse,
    summary="按文档推荐练习题",
)
async def get_recommendations_by_document(
    document_id: int,
    single_count: int = Query(5, ge=0, le=100, description="单选题数量"),
    multiple_count: int = Query(5, ge=0, le=100, description="多选题数量"),
    judge_count: int = Query(5, ge=0, le=100, description="判断题数量"),
    essay_count: int = Query(2, ge=0, le=50, description="简答题数量"),
    include_manual: bool = Query(True, description="是否补充人工题"),
    user_id: str | None = Query(None, description="可选：用户ID，用于行为重排"),
    db: Session = Depends(get_db),
):
    try:
        data = recommend_by_document(
            db=db,
            document_id=document_id,
            single_count=single_count,
            multiple_count=multiple_count,
            judge_count=judge_count,
            essay_count=essay_count,
            include_manual=include_manual,
            user_id=user_id,
        )
    except ValueError as exc:
        raise HTTPException(status_code=404, detail=str(exc)) from exc
    return data


@router.get(
    "/by-question",
    response_model=ByQuestionRecommendationResponse,
    summary="按错题推荐相关题目",
)
async def get_recommendations_by_question(
    question_type: str = Query(..., description="题型：single/multiple/judge/essay"),
    question_id: int = Query(..., ge=1, description="题目ID"),
    limit: int = Query(10, ge=1, le=50, description="推荐数量上限"),
    user_id: str | None = Query(None, description="可选：用户ID，用于行为重排"),
    db: Session = Depends(get_db),
):
    try:
        data = recommend_by_question(
            db=db,
            question_type=question_type,
            question_id=question_id,
            limit=limit,
            user_id=user_id,
        )
    except ValueError as exc:
        detail = str(exc)
        status_code = 400
        if detail == "错题不存在":
            status_code = 404
        raise HTTPException(status_code=status_code, detail=detail) from exc
    return data


@router.post(
    "/build-manual-knowledge-rel",
    summary="为人工作业题目生成知识点关联",
)
async def post_build_manual_knowledge_rel(db: Session = Depends(get_db)):
    """
    遍历四张题库表中 document_id 为空的题目，根据题干与知识点标题/内容的简单匹配，
    自动写入 question_knowledge_rel。用于支持「按错题推荐」时也能召回人工题。
    """
    try:
        # #region agent log
        _debug_log("api/recommendations.py:build_manual:entry", "build manual knowledge rel request", {}, "H2")
        # #endregion
        result = build_manual_question_knowledge_rel(db)
        # #region agent log
        _debug_log("api/recommendations.py:build_manual:exit", "build manual knowledge rel success", result, "H2")
        # #endregion
    except Exception as exc:
        # #region agent log
        _debug_log("api/recommendations.py:build_manual:error", "build manual knowledge rel failed", {
            "error": str(exc),
        }, "H2")
        # #endregion
        raise HTTPException(status_code=500, detail=str(exc)) from exc
    return result


@router.get(
    "/by-profile/{user_id}",
    summary="按用户画像推荐练习题",
)
async def get_recommendations_by_profile(
    user_id: str,
    single_count: int = Query(5, ge=0, le=100),
    multiple_count: int = Query(5, ge=0, le=100),
    judge_count: int = Query(5, ge=0, le=100),
    essay_count: int = Query(2, ge=0, le=50),
    db: Session = Depends(get_db),
):
    try:
        return recommend_by_profile(
            db=db,
            user_id=user_id,
            single_count=single_count,
            multiple_count=multiple_count,
            judge_count=judge_count,
            essay_count=essay_count,
        )
    except ValueError as exc:
        raise HTTPException(status_code=404, detail=str(exc)) from exc


@router.post(
    "/behaviors/record",
    summary="记录用户作答行为（用于后续推荐重排）",
)
async def record_behavior(body: dict, db: Session = Depends(get_db)):
    user_id = str(body.get("user_id") or "").strip()
    question_type = str(body.get("question_type") or "").strip().lower()
    question_id = int(body.get("question_id") or 0)
    is_correct = 1 if int(body.get("is_correct", 0) or 0) == 1 else 0
    time_spent_sec = max(0, int(body.get("time_spent_sec", 0) or 0))
    if not user_id or question_type not in ("single", "multiple", "judge", "essay") or question_id <= 0:
        raise HTTPException(status_code=400, detail="参数不合法")
    db.add(UserQuestionBehavior(
        user_id=user_id,
        question_type=question_type,
        question_id=question_id,
        is_correct=is_correct,
        time_spent_sec=time_spent_sec,
    ))
    db.commit()
    return {"recorded": True}


@router.post(
    "/profiles/upsert",
    summary="创建/更新用户画像",
)
async def upsert_profile(body: dict, db: Session = Depends(get_db)):
    user_id = str(body.get("user_id") or "").strip()
    if not user_id:
        raise HTTPException(status_code=400, detail="user_id 必填")
    department = body.get("department")
    position = body.get("position")
    interests = body.get("interests") or []
    profile = db.query(UserProfile).filter(UserProfile.user_id == user_id).first()
    if not profile:
        profile = UserProfile(user_id=user_id)
        db.add(profile)
    profile.department = department
    profile.position = position
    profile.interests = json.dumps(interests, ensure_ascii=False)
    db.commit()
    return {"upserted": True, "user_id": user_id}

