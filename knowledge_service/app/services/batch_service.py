"""
考核批次服务 —— bank_id_range 解析工具
"""

import logging
import re
from typing import List

logger = logging.getLogger(__name__)


def parse_bank_id_range(range_str: str) -> List[int]:
    """
    解析 bank_id_range 字符串为整数列表。

    支持格式：
      - "1-5"       → [1, 2, 3, 4, 5]
      - "1,3,5"     → [1, 3, 5]
      - "1-3,7,9"   → [1, 2, 3, 7, 9]
      - "3"         → [3]
      - ""          → []

    异常格式返回空列表，不抛出异常。
    """
    if not range_str or not range_str.strip():
        return []

    result: List[int] = []
    parts = range_str.strip().split(",")

    for part in parts:
        part = part.strip()
        if not part:
            continue
        # 尝试匹配范围格式 "a-b"
        range_match = re.match(r"^(\d+)\s*-\s*(\d+)$", part)
        if range_match:
            start, end = int(range_match.group(1)), int(range_match.group(2))
            result.extend(range(start, end + 1))
        else:
            # 单个数字
            try:
                result.append(int(part))
            except ValueError:
                logger.warning("parse_bank_id_range: 忽略无效片段 '%s'", part)
                continue

    return result
