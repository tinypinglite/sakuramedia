#!/usr/bin/env python3
"""生成应用内嵌的 CJK 子集字体 (assets/fonts/NotoSansSC-subset.ttf)。

为什么需要它
  Flutter Web 用 CanvasKit 渲染, 不内嵌中日文字体时, 首屏会去 fonts.gstatic.com
  按需下载 Noto fallback, 下载完成前中日文显示为方块字 (tofu), 国内网络尤其严重,
  甚至一直下载不出来。内嵌一个覆盖中日常用字的子集并设为主 fontFamily 即可根治。

字符集 ("标准" 档位)
  - GB2312 全 6763 简体常用字
  - Shift-JIS 全日文常用 (假名 + JIS 第一/二水准汉字 + 记号)
  - ASCII / Latin-1 补充 / 通用与 CJK 标点 / 全角半角形式
  实测覆盖中日常用字 + 女优艺名高频字 (咲/結/恵/実/桜 等), 子集约 5.5MB。
  极生僻字仍由引擎的 Noto fallback 联网兜底, 概率极低。

源字体
  Noto Sans CJK SC (思源黑体简体, pan-CJK 全集, 含中日文与假名)。
  默认读取 assets/fonts/NotoSansSC.ttf; 该文件体积大、未纳入版本库 (.gitignore),
  重裁前请先下载源字体放到该路径:
    https://github.com/notofonts/noto-cjk/releases  (Noto Sans CJK SC)

用法
  pip install fonttools
  python3 tool/subset_font.py [源字体路径] [输出路径]
  默认: assets/fonts/NotoSansSC.ttf -> assets/fonts/NotoSansSC-subset.ttf
"""
import os
import sys

from fontTools.subset import Options, Subsetter
from fontTools.ttLib import TTFont

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC = sys.argv[1] if len(sys.argv) > 1 else os.path.join(ROOT, "assets/fonts/NotoSansSC.ttf")
OUT = sys.argv[2] if len(sys.argv) > 2 else os.path.join(ROOT, "assets/fonts/NotoSansSC-subset.ttf")


def _decode_charset(byte_pairs):
    """枚举给定编码的合法码位, 返回能解码出的字符集合。"""
    chars = set()
    for encoding, his, los in byte_pairs:
        for hi in his:
            for lo in los:
                try:
                    chars.add(bytes([hi, lo]).decode(encoding))
                except Exception:
                    pass
    return chars


def _gb2312():
    return _decode_charset([("gb2312", range(0xB0, 0xF8), range(0xA1, 0xFF))])


def _shift_jis():
    his = list(range(0x81, 0xA0)) + list(range(0xE0, 0xFD))
    los = list(range(0x40, 0x7F)) + list(range(0x80, 0xFD))
    return _decode_charset([("shift_jis", his, los)])


def _ranges(spans):
    chars = set()
    for start, end in spans:
        chars.update(chr(cp) for cp in range(start, end + 1))
    return chars


def main():
    if not os.path.exists(SRC):
        sys.exit(
            f"源字体不存在: {SRC}\n"
            "请先下载 Noto Sans CJK SC 放到该路径 (见本文件头部注释)。"
        )

    charset = _ranges([
        (0x0020, 0x007E),  # ASCII
        (0x00A0, 0x00FF),  # Latin-1 补充
        (0x2000, 0x206F),  # 通用标点
        (0x3000, 0x303F),  # CJK 标点
        (0x3040, 0x309F),  # 平假名
        (0x30A0, 0x30FF),  # 片假名
        (0xFF00, 0xFFEF),  # 全角/半角形式
    ]) | _gb2312() | _shift_jis()

    font = TTFont(SRC)
    subsetter = Subsetter(options=Options())
    subsetter.populate(unicodes=[ord(c) for c in charset])
    subsetter.subset(font)
    font.save(OUT)

    size_mb = os.path.getsize(OUT) / 1024 / 1024
    print(f"已生成 {OUT}  ({size_mb:.2f}MB, {len(font.getBestCmap())} glyphs)")


if __name__ == "__main__":
    main()
