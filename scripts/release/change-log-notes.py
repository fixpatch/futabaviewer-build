#!/usr/bin/env python3
"""本体の更新履歴(change_log.html)から、そのタグの節だけを抜き出して変更点にする。

Release の説明文(Obtainium の「変更点」に出る)と、SideStore / AltStore / LiveContainer の
source.json の localizedDescription(「What's New」に出る)に使う。

更新履歴の書式(master / old-ui 共通):
    <p class="green">v3.0.2β Based 非公式 FixPatch20-1 (26.9.18)</p>
    <p class="str">
        ■見出し<br />
        ・項目<br />
        　続きの行(全角スペースで始まる)<br />
    </p>

出力:
    <出力先>.md  … Markdown(■→太字、・→箇条書き、続きの行は箇条書きの中へ)
    <出力先>.txt … そのままの文(SideStore は Markdown を解さないので ■・ をそのまま使う)
節が見つからなければ何も書かずに終わる(呼ぶ側が「アプリ内の更新履歴を参照」に倒す)。

引数: 本体のソースのディレクトリ、タグ、出力先(拡張子なし)
"""
import html
import os
import re
import sys

source_dir, tag, output = sys.argv[1:4]

candidates = [
    "core/resources/src/commonMain/composeResources/files/change_log.html",  # master
    "app/src/main/assets/change_log.html",  # old-ui
]
path = next((os.path.join(source_dir, c) for c in candidates if os.path.exists(os.path.join(source_dir, c))), None)
if path is None:
    print("::warning::change_log.html が見つかりません")
    sys.exit(0)

with open(path, encoding="utf-8") as f:
    text = f.read()

heading = re.compile(r'<p class="green">(.*?)</p>', re.S)
headings = list(heading.finditer(text))
# タグは語として一致させる(FixPatch20 が FixPatch20-1 に当たらないように)。
own = re.compile(r"(?<![0-9A-Za-z-])" + re.escape(tag) + r"(?![0-9A-Za-z-])")
index = next((i for i, m in enumerate(headings) if own.search(m.group(1))), None)
if index is None:
    print(f"::warning::更新履歴に {tag} の節がありません")
    sys.exit(0)

start = headings[index].end()
end = headings[index + 1].start() if index + 1 < len(headings) else text.find("</div>", start)
body = text[start:end if end >= 0 else len(text)]

body = re.sub(r"<!--.*?-->", "", body, flags=re.S)
# \s は全角スペースも食うので使わない(続きの行の目印が消える)。
body = re.sub(r"[ \t\r\n]*<br[ \t]*/?>[ \t\r\n]*", "\n", body, flags=re.I)
body = re.sub(r"<[^>]+>", "", body)
lines = []
for raw in html.unescape(body).split("\n"):
    line = raw.strip(" \t\r")
    if line.strip("　"):
        lines.append(line)

if not lines:
    print(f"::warning::{tag} の節が空です")
    sys.exit(0)

markdown = []
for line in lines:
    if line.startswith("■"):
        if markdown:
            markdown.append("")
        markdown.append(f"**{line[1:].strip()}**")
        markdown.append("")
    elif line.startswith("・"):
        markdown.append(f"- {line[1:].strip()}")
    elif line.startswith("　"):
        # 続きの行。直前の箇条書きの中で改行して続ける。
        markdown.append(f"  {line.strip(chr(0x3000)).strip()}")
    else:
        markdown.append(line)

# 続きの行は Markdown の改行(行末の空白2つ)でつなぐ。
for i in range(len(markdown) - 1):
    if markdown[i + 1].startswith("  ") and markdown[i]:
        markdown[i] += "  "

with open(output + ".md", "w", encoding="utf-8", newline="\n") as f:
    f.write("\n".join(markdown).strip() + "\n")
with open(output + ".txt", "w", encoding="utf-8", newline="\n") as f:
    f.write("\n".join(lines).strip() + "\n")
print(f"{path}: {tag} の変更点 {len(lines)} 行")
