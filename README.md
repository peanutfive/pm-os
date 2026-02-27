# PM-OS：产品经理 AI 工作系统

> Product Management Operating System: A logic-first, documentation-as-code repository for streamlining PRD generation and requirement modeling via AI-native workflows.

基于 Cursor AI 的产品经理工作流增强系统，包含需求梳理和 PRD 撰写的 Skill 与 Rules。

## 项目结构

```
pm-os/
├── .cursor/
│   ├── rules/                              # 项目规则（Prompt 层）
│   │   ├── pm-workflow.mdc                 # PM 工作流思维框架
│   │   ├── prd-writing.mdc                 # PRD 写作规范
│   │   └── requirement-analysis.mdc        # 需求分析方法论
│   └── skills/                             # 项目技能（执行层）
│       └── pm-prd-writer/
│           ├── SKILL.md                    # 主技能入口
│           ├── templates/                  # 文档模板
│           │   ├── prd-template.md         # PRD 模板
│           │   ├── requirement-template.md # 需求梳理模板
│           │   └── user-story-template.md  # 用户故事模板
│           └── examples/                   # 参考示例
│               ├── prd-example.md          # PRD 示例
│               └── requirement-example.md  # 需求梳理示例
├── docs/                                   # 输出文档
│   ├── prds/                               # PRD 文档存放
│   └── requirements/                       # 需求文档存放
├── README.md
└── .gitignore
```

## 架构说明

| 层级 | 路径 | 作用 |
|------|------|------|
| **Rules（思维框架）** | `.cursor/rules/` | 定义 AI 的工作准则和认知模式，始终生效 |
| **Skills（执行引擎）** | `.cursor/skills/` | 提供具体任务的执行流程、模板和示例 |
| **Docs（输出产物）** | `docs/` | 存放生成的 PRD 和需求文档 |

## 使用方式

1. 在 Cursor 中打开本项目
2. Rules 会自动加载，AI 将以产品经理视角工作
3. 对话中提到"需求梳理"或"写PRD"时，Skill 会自动触发
4. 生成的文档保存在 `docs/` 目录下

## 快速开始

```
# 克隆项目
git clone https://github.com/peanutfive/pm-os.git

# 用 Cursor 打开
cursor pm-os
```

然后在 Cursor 中直接对话：

- "帮我梳理一下XX功能的需求"
- "帮我写一份XX功能的PRD"
- "用用户故事的方式描述XX场景"
