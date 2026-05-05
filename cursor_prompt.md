# 任务目标：为 EnerQuote 开发“项目级报价持久化”功能

## 1. 业务背景
当前应用是一个面向海外市场的光伏与储能 (PV+ESS) 报价工具。目前的测算属于“瞬时计算”，未进行数据落库。
现在需要重构应用架构，引入“项目管理”概念。用户需要先创建“项目 (Project)”，在特定项目下进行多次“测算报价 (Quote/Calculation)”，实现历史版本的持久化和复用。

## 2. 技术栈约束
* **后端/数据库**：使用 Neon.tech (PostgreSQL) + FastAPI (Python)。
* **前端**：Flutter。
* **鉴权**：目前已接入 Firebase Auth，所有接口调用需验证用户身份。

## 3. 数据库 Schema 设计要求 (PostgreSQL)
请帮我生成以下两张表的 SQL 建表语句或 SQLAlchemy 模型代码：

**表 A: projects (项目表)**
* `id`: UUID (主键)
* `user_id`: String (关联 Firebase UID，必填)
* `project_name`: String (如 "Texas Walmart Rooftop")
* `client_name`: String (客户名称，选填)
* `location`: String (项目地址，选填)
* `created_at`: Timestamp
* `updated_at`: Timestamp

**表 B: project_calculations (测算版本表)**
* `id`: UUID (主键)
* `project_id`: UUID (外键关联 projects.id)
* `version_name`: String (版本备注，如 "V1-基础方案")
* `parameters`: JSONB (核心！用于完整存储用户当时的输入参数：如组件型号、逆变器、损耗系数、阶梯电价等，以便复原)
* `results`: JSONB (存储计算结果：如 ROI、LCOE、Total Cost，用于列表页快速展示，无需重新计算)
* `created_at`: Timestamp

## 4. 后端 API 接口需求 (FastAPI)
请实现以下 RESTful API 骨架：
1.  `GET /projects`: 获取当前用户的项目列表（按时间倒序）。
2.  `POST /projects`: 创建新项目。
3.  `GET /projects/{id}/calculations`: 获取某个项目下的所有历史测算版本。
4.  `POST /projects/{id}/calculations`: 将当前屏幕的测算参数和结果保存为一个新版本。

## 5. Flutter 前端 UI 重构要求
请给出核心页面的代码重构思路或具体代码：
1.  **ProjectListScreen (项目列表页)**：作为 App 的新首页。展示历史项目，支持点击进入详情，右上角有“新建项目”按钮。
2.  **ProjectDetailScreen (项目详情页)**：展示该项目的基础信息，以及下方的一个 ListView（显示所有关联的历史 `project_calculations`）。
3.  **CalculationScreen (计算器页面) 的状态修改**：
    * 页面需接收一个可选的 `projectId` 和 `calculationId`。
    * 如果有 `calculationId`，在 `initState` 中解析 `parameters` 的 JSON 数据，还原 UI 表单状态。
    * 用户点击“保存方案”时，调用后台接口，将表单数据打包成 JSONB 存入 `project_calculations`。

## 6. 执行步骤
请先确认你是否理解了以上需求？如果理解，请**首先**输出后端数据库的设计和 FastAPI 接口代码，待我确认后再生成 Flutter 侧的 UI 代码。