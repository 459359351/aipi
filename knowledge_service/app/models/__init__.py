from .document import Document
from .knowledge_point import KnowledgePoint
from .tag import Tag
from .father_tag import FatherTag
from .knowledge_tag_rel import knowledge_tag_rel
from .question_tag_rel import question_tag_rel
from .question_knowledge_rel import QuestionKnowledgeRel
from .question import SingleChoice, MultipleChoice, Judge, Essay, QuestionTask
from .document_tag_rel import DocumentTagRel
from .question_audit_log import QuestionAuditLog
from .user_profile import UserProfile
from .user_question_behavior import UserQuestionBehavior

__all__ = [
    "Document", "KnowledgePoint", "Tag", "FatherTag", "knowledge_tag_rel", "question_tag_rel",
    "QuestionKnowledgeRel", "DocumentTagRel",
    "SingleChoice", "MultipleChoice", "Judge", "Essay", "QuestionTask",
    "QuestionAuditLog", "UserProfile", "UserQuestionBehavior",
]

