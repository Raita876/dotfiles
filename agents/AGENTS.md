# Global Agent Instructions

すべてのエージェント向けの共通指示。Claude Code は `~/.claude/CLAUDE.md`、Codex は `~/.codex/AGENTS.md` として読み込む。
細かいルールは `shared/` に分けて、`@~/.claude/shared/<name>.md` で読み込む。
ただし Codex は `@` の読み込みに対応していないので、Codex にも効かせたいルールはこのファイルに直接書く。

## 言語

- 返答は日本語で書く
