# 无人机影像标注工具

## 项目概述
单文件 HTML5 无人机影像标注工具，用于在航拍图上框选颜色区域并导出。

## 核心文件
- **标注工具.html** — 主程序，包含完整 HTML/CSS/JS（单文件架构）
- **标注工具.exe** — .NET 启动器，将 HTML 解压到临时目录后用 Edge 应用模式打开
- **build_exe.ps1** — 从 HTML 重新编译 EXE（需 .NET Framework 4.x）

## 修改指南
- 所有功能在 `标注工具.html` 的 `<script>` 标签内
- JS 为压缩格式（无换行无注释），修改时注意保持括号平衡
- 修改 HTML 后运行 `build_exe.ps1` 同步更新 EXE
- 工具链：PowerShell + .NET csc.exe（Win10/11 自带）

## 关键 JS 结构
- `state` — 全局状态（images, polygons, mode, colors, zoom 等）
- `render()` — 主渲染函数，绘制图片+线框+标签
- `autoSelectRegion()` — 魔术棒自动框选（flood fill + 矩形范围）
- `exportImage()` — 无损导出 PNG（toDataURL）
- `exportAnnotations()` — 导出 JSON 坐标数据
- `drawSmoothPolygon()` — Catmull-Rom 平滑曲线
- `rebuildLayerPanel()` — 左侧图层面板刷新

## 功能清单
- 手绘多边形 / 自动矩形框选 / 吸管取色
- 图层管理：多选(Ctrl+点击)、批量改色、显隐切换
- 线宽/容差可调，线框/名称独立显隐
- 导出 JSON / PNG
- 重叠检测（零容忍）
## 版本管理
- `VERSION` — 当前版本号 + 日期
- `CHANGELOG.md` — 详细更新日志
- `versions/` — 各版本 HTML 快照（v1.0.0_日期.html）
- `version.ps1` — 版本管理脚本
  - `-list` 查看所有版本
  - `-save` 保存当前为新版本
  - `-diff -v1 x -v2 y` 对比两个版本

## 版本升级流程
1. 修改 `标注工具.html`
2. 运行 `.\version.ps1 -save` 保存快照
3. 输入新版本号和改动描述
4. 运行 `.\build_exe.ps1` 更新 EXE