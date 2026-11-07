# Публикация на GitHub

## Параметры репозитория

- **Name:** `kill-all-eggs-3d`
- **Description (RU):** 3D-экшен-выживалка на Godot 4.7: сбивай яйца, отбивайся от хедкрабов, чужих и лицехватов, пройди 10 волн и открой одну из 5 концовок.
- **Description (EN):** A Godot 4.7 3D survival shooter: smash eggs, fight headcrabs, xenomorphs and facehuggers, survive 10 waves and unlock 5 endings.
- **Topics:** `godot`, `godot-engine`, `godot4`, `gamedev`, `game`, `3d`, `survival`, `shooter`, `aliens`, `open-source`
- **License:** MIT
- **Default branch:** `main`

## Первый push

Если репозиторий ещё не создан на GitHub:

1. Создайте пустой репозиторий `kill-all-eggs-3d` **без** README, .gitignore и лицензии — они уже есть в проекте.
2. Выполните в папке проекта:

```bash
git init -b main
git add .
git commit -m "Initial commit: Убить все яйца и выжить 3D"
git remote add origin https://github.com/b0unc3r-nm/kill-all-eggs-3d.git
git push -u origin main
```

Если Git уже инициализирован и первый коммит сделан, достаточно:

```bash
git remote add origin https://github.com/b0unc3r-nm/kill-all-eggs-3d.git
git push -u origin main
```

## После публикации

- В разделе **About** вставьте описание и топики выше.
- В **Settings → Pages** можно включить GitHub Pages, но для игры это не обязательно.
- Для запуска игры из исходников пользователям нужен Godot 4.7+.
- Если будете добавлять экспортированные сборки, прикрепите их к **Releases**, а не коммитьте в репозиторий.
