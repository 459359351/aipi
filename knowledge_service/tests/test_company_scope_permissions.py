from __future__ import annotations

import random
import unittest

from sqlalchemy import create_engine, event
from sqlalchemy.orm import sessionmaker

from knowledge_service.app.database import Base
from knowledge_service.app.models.document import Document
from knowledge_service.app.models.document_company_scope_rel import DocumentCompanyScopeRel
from knowledge_service.app.models.question import Essay, Judge, MultipleChoice, SingleChoice
from knowledge_service.app.models.question_company_scope_rel import QuestionCompanyScopeRel
from fastapi import HTTPException
from knowledge_service.app.security.company_scope import CompanyScope, validate_target_company_ids
from knowledge_service.app.services import document_service
from knowledge_service.app.services.question_scope_service import get_visible_question
from knowledge_service.app.services.question_text_matcher import find_similar_by_text


def _build_session():
    engine = create_engine("sqlite+pysqlite:///:memory:", future=True)

    @event.listens_for(engine, "connect")
    def _register_sqlite_functions(dbapi_connection, _connection_record):
        dbapi_connection.create_function("rand", 0, random.random)

    Base.metadata.create_all(
        bind=engine,
        tables=[
            Document.__table__,
            DocumentCompanyScopeRel.__table__,
            SingleChoice.__table__,
            MultipleChoice.__table__,
            Judge.__table__,
            Essay.__table__,
            QuestionCompanyScopeRel.__table__,
        ],
    )
    session_factory = sessionmaker(bind=engine, autocommit=False, autoflush=False)
    return session_factory()


class CompanyScopePermissionTests(unittest.TestCase):
    def test_branch_admin_cannot_bind_other_company_ids(self):
        scope = CompanyScope(role="branch_admin", company_id="branch-a")

        with self.assertRaises(HTTPException) as ctx:
            validate_target_company_ids(scope, ["branch-b"], required=True)

        self.assertEqual(ctx.exception.status_code, 403)

    def test_document_scope_filter_hides_unbound_history_from_branch_admin(self):
        db = _build_session()
        try:
            doc_a = Document(id=1, doc_name="A文档", status="completed")
            doc_b = Document(id=2, doc_name="B文档", status="completed")
            doc_unbound = Document(id=3, doc_name="历史空归属文档", status="completed")
            db.add_all([doc_a, doc_b, doc_unbound])
            db.flush()
            db.add_all(
                [
                    DocumentCompanyScopeRel(id=1, document_id=doc_a.id, company_id="branch-a"),
                    DocumentCompanyScopeRel(id=2, document_id=doc_b.id, company_id="branch-b"),
                ]
            )
            db.commit()

            branch_scope = CompanyScope(role="branch_admin", company_id="branch-a")
            global_scope = CompanyScope(role="global_admin", company_id="GLOBAL")

            branch_docs, branch_total = document_service.get_documents_list(db, scope=branch_scope)
            global_docs, global_total = document_service.get_documents_list(db, scope=global_scope)

            self.assertEqual(branch_total, 1)
            self.assertEqual([doc.doc_name for doc in branch_docs], ["A文档"])
            self.assertEqual(global_total, 3)
            self.assertEqual(
                {doc.doc_name for doc in global_docs},
                {"A文档", "B文档", "历史空归属文档"},
            )
            self.assertIsNone(document_service.get_document_by_id(db, doc_unbound.id, scope=branch_scope))
            self.assertIsNotNone(document_service.get_document_by_id(db, doc_unbound.id, scope=global_scope))
        finally:
            db.close()

    def test_text_matcher_and_question_lookup_only_return_visible_questions(self):
        db = _build_session()
        try:
            doc_a = Document(id=1, doc_name="A文档", status="completed")
            doc_b = Document(id=2, doc_name="B文档", status="completed")
            db.add_all([doc_a, doc_b])
            db.flush()
            db.add_all(
                [
                    DocumentCompanyScopeRel(id=1, document_id=doc_a.id, company_id="branch-a"),
                    DocumentCompanyScopeRel(id=2, document_id=doc_b.id, company_id="branch-b"),
                ]
            )

            q_doc_visible = SingleChoice(
                id=1,
                document_id=doc_a.id,
                question_text="党员教育培训制度要求是什么",
                option_a="A",
                option_b="B",
                option_c="C",
                option_d="D",
                correct_answer="A",
            )
            q_doc_hidden = SingleChoice(
                id=2,
                document_id=doc_b.id,
                question_text="党员教育培训制度要求是什么",
                option_a="A",
                option_b="B",
                option_c="C",
                option_d="D",
                correct_answer="A",
            )
            q_orphan_visible = SingleChoice(
                id=3,
                document_id=None,
                question_text="党员教育培训制度的实施要求",
                option_a="A",
                option_b="B",
                option_c="C",
                option_d="D",
                correct_answer="A",
            )
            q_orphan_hidden = SingleChoice(
                id=4,
                document_id=None,
                question_text="党员教育培训制度的实施要求",
                option_a="A",
                option_b="B",
                option_c="C",
                option_d="D",
                correct_answer="A",
            )
            db.add_all([q_doc_visible, q_doc_hidden, q_orphan_visible, q_orphan_hidden])
            db.flush()
            db.add_all(
                [
                    QuestionCompanyScopeRel(
                        id=1,
                        question_type="single",
                        question_id=q_orphan_visible.id,
                        company_id="branch-a",
                    ),
                    QuestionCompanyScopeRel(
                        id=2,
                        question_type="single",
                        question_id=q_orphan_hidden.id,
                        company_id="branch-b",
                    ),
                ]
            )
            db.commit()

            branch_scope = CompanyScope(role="branch_admin", company_id="branch-a")

            self.assertIsNotNone(get_visible_question(db, branch_scope, "single", q_doc_visible.id))
            self.assertIsNotNone(get_visible_question(db, branch_scope, "single", q_orphan_visible.id))
            self.assertIsNone(get_visible_question(db, branch_scope, "single", q_doc_hidden.id))
            self.assertIsNone(get_visible_question(db, branch_scope, "single", q_orphan_hidden.id))

            matches = find_similar_by_text(
                db=db,
                source_question_text="党员教育培训制度要求",
                limit=10,
                scope=branch_scope,
            )
            matched_ids = {question_id for _, question_id, _ in matches}
            self.assertIn(q_doc_visible.id, matched_ids)
            self.assertIn(q_orphan_visible.id, matched_ids)
            self.assertNotIn(q_doc_hidden.id, matched_ids)
            self.assertNotIn(q_orphan_hidden.id, matched_ids)
        finally:
            db.close()


if __name__ == "__main__":
    unittest.main()
