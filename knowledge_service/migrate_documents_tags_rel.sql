DROP TABLE IF EXISTS documents_tags_rel;

CREATE TABLE documents_tags_rel (
    id            BIGINT AUTO_INCREMENT PRIMARY KEY,
    document_id   BIGINT NOT NULL,
    father_tag_id BIGINT NULL,
    tag_id        BIGINT NULL,
    created_at    DATETIME DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_dtr_document   FOREIGN KEY (document_id)   REFERENCES documents(id)   ON DELETE CASCADE,
    CONSTRAINT fk_dtr_father_tag FOREIGN KEY (father_tag_id) REFERENCES father_tags(id) ON DELETE CASCADE,
    CONSTRAINT fk_dtr_tag        FOREIGN KEY (tag_id)        REFERENCES tags(id)        ON DELETE CASCADE,
    INDEX idx_dtr_doc (document_id),
    INDEX idx_dtr_father_tag (father_tag_id),
    INDEX idx_dtr_tag (tag_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
