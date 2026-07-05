# drupal.conf 骨架化重构 Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** 将 `install/etc/nginx/sites.available/drupal.conf` 改造为 nfrastack 七锚点骨架结构，并将 `server.conf.d/http/drupal-maps.conf` 迁移到 `sites.enabled/drupal/server-pre/`，使所有 Drupal 专属 nginx 配置统一在单一目录下。

**Architecture:** 在 drupal.conf 的七个指定位置插入 `include sites.enabled/drupal/*/*.conf;` 锚点（保留所有现有指令与 sed 目标字符串），并把 http 级 `map` 配置从 `server.conf.d/http/` 迁到 `sites.enabled/drupal/server-pre/`（这是锚点中唯一会被实际加载的目录）。

**Tech Stack:** nginx 配置、bash 脚本（验证用）、git

---

## 任务总览

- Task 1: 创建 `server-pre/` 目录并迁移 `drupal-maps.conf`
- Task 2: 删除原始 `drupal-maps.conf`
- Task 3: 修改 `drupal.conf` —— 插入 7 个 include 锚点（一次性修改 + 5 项验证）
- Task 4: 端到端验证 + 提交

---

## Task 1: 创建 `server-pre/` 目录并复制 `drupal-maps.conf`

**Files:**
- Create: `install/etc/nginx/sites.enabled/drupal/server-pre/drupal-maps.conf`
- Read source: `install/etc/nginx/server.conf.d/http/drupal-maps.conf`

**Step 1: 创建目标目录**

```bash
mkdir -p /Users/terry/docker/davyinsa/docker-nginx-php/install/etc/nginx/sites.enabled/drupal/server-pre
```

预期：无输出，目录创建成功。

**Step 2: 复制 drupal-maps.conf 到新位置**

```bash
cp /Users/terry/docker/davyinsa/docker-nginx-php/install/etc/nginx/server.conf.d/http/drupal-maps.conf \
   /Users/terry/docker/davyinsa/docker-nginx-php/install/etc/nginx/sites.enabled/drupal/server-pre/drupal-maps.conf
```

预期：无输出。

**Step 3: 验证字节级一致**

```bash
diff /Users/terry/docker/davyinsa/docker-nginx-php/install/etc/nginx/server.conf.d/http/drupal-maps.conf \
     /Users/terry/docker/davyinsa/docker-nginx-php/install/etc/nginx/sites.enabled/drupal/server-pre/drupal-maps.conf && \
echo "FILES_IDENTICAL"
```

预期：输出 `FILES_IDENTICAL`（diff 无差异）。

**Step 4: 提交**

```bash
cd /Users/terry/docker/davyinsa/docker-nginx-php
git add install/etc/nginx/sites.enabled/drupal/server-pre/drupal-maps.conf
git commit -m "refactor: migrate drupal-maps.conf to sites.enabled/drupal/server-pre/

Move http-level map directives under the new sites-enabled skeleton tree
where they will be loaded via the server-pre anchor in drupal.conf.

Co-Authored-By: Claude <noreply@anthropic.com>"
```

预期：提交成功，1 个文件新增。

---

## Task 2: 删除原始 `drupal-maps.conf`

**Files:**
- Delete: `install/etc/nginx/server.conf.d/http/drupal-maps.conf`
- Optional cleanup: 若目录变空则保留目录壳（含 `.gitkeep`）

**Step 1: 删除原始文件**

```bash
rm /Users/terry/docker/davyinsa/docker-nginx-php/install/etc/nginx/server.conf.d/http/drupal-maps.conf
```

预期：无输出。

**Step 2: 确认目录状态**

```bash
ls -la /Users/terry/docker/davyinsa/docker-nginx-php/install/etc/nginx/server.conf.d/http/
```

预期：目录存在（可能为空，或仅含 `.gitkeep`）。若是 nginx base image 仍会 `include /etc/nginx/server.conf.d/http/*.conf;`，空目录即空 glob 无害。

**Step 3: 提交**

```bash
cd /Users/terry/docker/davyinsa/docker-nginx-php
git add -u install/etc/nginx/server.conf.d/http/drupal-maps.conf
git commit -m "refactor: remove original drupal-maps.conf from server.conf.d/http/

Now loaded via sites.enabled/drupal/server-pre/drupal-maps.conf.

Co-Authored-By: Claude <noreply@anthropic.com>"
```

预期：提交成功，1 个文件删除。

---

## Task 3: 修改 `drupal.conf` —— 插入 7 个 include 锚点

**Files:**
- Modify: `install/etc/nginx/sites.available/drupal.conf`

**前置准备：备份与确认基线**

**Step 1: 记录当前行数**

```bash
wc -l /Users/terry/docker/davyinsa/docker-nginx-php/install/etc/nginx/sites.available/drupal.conf
```

预期：输出 `178` 行。

**Step 2: 用 Edit 工具逐个插入锚点（按位置顺序）**

使用 Edit 工具，对 `install/etc/nginx/sites.available/drupal.conf` 进行以下 7 处修改（每次只插入一行锚点）：

**锚点 1：server-pre（文件开头、server 块外）**

在第 1 行注释 `## Reference: ...` 之后、第 2 行 `server {` 之前插入：
```nginx
include sites.enabled/drupal/server-pre/*.conf;

```
（锚点行后保留一个空行以与 server 块分隔）

精确 old_string（仅在文件中出现一次）：
```
## Reference: https://www.nginx.com/resources/wiki/start/topics/recipes/drupal/
server {
```

new_string：
```
## Reference: https://www.nginx.com/resources/wiki/start/topics/recipes/drupal/
include sites.enabled/drupal/server-pre/*.conf;

server {
```

**锚点 2：server-begin（listen/root 之后、add_header 之前）**

精确 old_string（仅在文件中出现一次）：
```
    listen 80;
    root /var/www/html;

    add_header X-Frame-Options SAMEORIGIN;
```

new_string：
```
    listen 80;
    root /var/www/html;

    include sites.enabled/drupal/server-begin/*.conf;

    add_header X-Frame-Options SAMEORIGIN;
```

**锚点 3：location-pre（现有 vhost.d/pre-*.conf 之前）**

精确 old_string：
```
    add_header Strict-Transport-Security "max-age=0";

    include /etc/nginx/vhost.d/pre-*.conf;
```

new_string：
```
    add_header Strict-Transport-Security "max-age=0";

    include sites.enabled/drupal/location-pre/*.conf;
    include /etc/nginx/vhost.d/pre-*.conf;
```

**锚点 4：location（第一个 location 块之前）**

精确 old_string：
```
    location @rewrite_subdir {
        rewrite ^ /index.php;
    }

    include /etc/nginx/extra/subdir.conf;

    location = /favicon.ico {
        log_not_found off;
        access_log off;
    }

    location ~ \..*/.*\.php$ {
        return 403;
    }

    location ~ ^/sites/.*/private/ {
        return 403;
    }

    location ~* ^/.well-known/ {
        allow all;
    }

    location ~ (^|/)\. {
        return 403;
    }

    location = / {
```

new_string：
```
    location @rewrite_subdir {
        rewrite ^ /index.php;
    }

    include /etc/nginx/extra/subdir.conf;

    location = /favicon.ico {
        log_not_found off;
        access_log off;
    }

    location ~ \..*/.*\.php$ {
        return 403;
    }

    location ~ ^/sites/.*/private/ {
        return 403;
    }

    location ~* ^/.well-known/ {
        allow all;
    }

    location ~ (^|/)\. {
        return 403;
    }

    include sites.enabled/drupal/location/*.conf;

    location = / {
```

**锚点 5：location-post（所有 location 块之后、方法检查之前）**

精确 old_string：
```
    location ~* \.mjs$ {
        types {
            text/javascript mjs;
        }
    }

    if ( $request_method !~ ^(GET|POST|PUT|PATCH|DELETE|HEAD)$ ) {
        return 405;
    }
```

new_string：
```
    location ~* \.mjs$ {
        types {
            text/javascript mjs;
        }
    }

    include sites.enabled/drupal/location-post/*.conf;

    if ( $request_method !~ ^(GET|POST|PUT|PATCH|DELETE|HEAD)$ ) {
        return 405;
    }
```

**锚点 6：server-end（方法检查之后、现有 vhost.d/post-*.conf 之前）**

精确 old_string：
```
    if ( $request_method !~ ^(GET|POST|PUT|PATCH|DELETE|HEAD)$ ) {
        return 405;
    }
    include /etc/nginx/vhost.d/post-*.conf;
}
```

new_string：
```
    if ( $request_method !~ ^(GET|POST|PUT|PATCH|DELETE|HEAD)$ ) {
        return 405;
    }

    include sites.enabled/drupal/server-end/*.conf;
    include /etc/nginx/vhost.d/post-*.conf;
}
```

**锚点 7：server-post（server 块闭合 `}` 之后、文件末尾）**

精确 old_string：
```
    include /etc/nginx/vhost.d/post-*.conf;
}
```

new_string（注意：第 6 步已改过这一段，所以这里要匹配新版本）：
```
    include sites.enabled/drupal/server-end/*.conf;
    include /etc/nginx/vhost.d/post-*.conf;
}

include sites.enabled/drupal/server-post/*.conf;
```

**Step 3: 验证锚点数量 = 7**

```bash
grep -c '^[[:space:]]*include sites\.enabled/drupal/' /Users/terry/docker/davyinsa/docker-nginx-php/install/etc/nginx/sites.available/drupal.conf
```

预期：输出 `7`。

**Step 4: 验证 sed 目标字符串原样存在**

```bash
grep -E '^[[:space:]]*listen 80;$' /Users/terry/docker/davyinsa/docker-nginx-php/install/etc/nginx/sites.available/drupal.conf && \
grep -E '^[[:space:]]*root /var/www/html;$' /Users/terry/docker/davyinsa/docker-nginx-php/install/etc/nginx/sites.available/drupal.conf && \
grep -E '^[[:space:]]*add_header X-Frame-Options SAMEORIGIN;$' /Users/terry/docker/davyinsa/docker-nginx-php/install/etc/nginx/sites.available/drupal.conf && \
grep -F 'add_header Content-Security-Policy "default-src '\''self'\'';";' /Users/terry/docker/davyinsa/docker-nginx-php/install/etc/nginx/sites.available/drupal.conf && \
echo "SED_TARGETS_OK"
```

预期：输出 `SED_TARGETS_OK`（四个 grep 都命中）。

**Step 5: 验证现有 include 行保留**

```bash
grep -E '^[[:space:]]*include /etc/nginx/vhost\.d/(pre|post)-\*\.' /Users/terry/docker/davyinsa/docker-nginx-php/install/etc/nginx/sites.available/drupal.conf && \
grep -E '^[[:space:]]*include /etc/nginx/extra/subdir\.conf;$' /Users/terry/docker/davyinsa/docker-nginx-php/install/etc/nginx/sites.available/drupal.conf && \
echo "EXISTING_INCLUDES_OK"
```

预期：输出 3 行（vhost.d/pre-、vhost.d/post-、extra/subdir.conf）+ `EXISTING_INCLUDES_OK`。

**Step 6: 验证文件总行数**

```bash
wc -l /Users/terry/docker/davyinsa/docker-nginx-php/install/etc/nginx/sites.available/drupal.conf
```

预期：约 `185` 行（178 + 7 行锚点；因部分插入含前置空行，最终可能为 184-186 之间，只要 sed 目标和 include 都在即视为成功）。

**Step 7: 提交**

```bash
cd /Users/terry/docker/davyinsa/docker-nginx-php
git add install/etc/nginx/sites.available/drupal.conf
git commit -m "refactor: scaffold drupal.conf with nfrastack 7-anchor include pattern

Insert include sites.enabled/drupal/{server-pre,server-begin,location-pre,
location,location-post,server-end,server-post}/*.conf anchors aligned with
upstream default.conf. All existing directives and include lines preserved;
40-drupal init script's sed targets remain unchanged.

Co-Authored-By: Claude <noreply@anthropic.com>"
```

预期：提交成功，1 个文件修改。

---

## Task 4: 端到端验证

**Step 1: 综合验证脚本（一次性跑完所有验收项）**

```bash
cd /Users/terry/docker/davyinsa/docker-nginx-php

DRUPAL_CONF=install/etc/nginx/sites.available/drupal.conf
NEW_MAPS=install/etc/nginx/sites.enabled/drupal/server-pre/drupal-maps.conf
OLD_MAPS=install/etc/nginx/server.conf.d/http/drupal-maps.conf

echo "=== 1. 锚点数量 ==="
ANCHORS=$(grep -c '^[[:space:]]*include sites\.enabled/drupal/' "$DRUPAL_CONF")
echo "锚点数: $ANCHORS (期望 7)"
[ "$ANCHORS" -eq 7 ] || { echo "FAIL: 锚点数量不等于 7"; exit 1; }

echo "=== 2. sed 目标字符串 ==="
grep -qE '^[[:space:]]*listen 80;$' "$DRUPAL_CONF" || { echo "FAIL: listen 80 不存在"; exit 1; }
grep -qE '^[[:space:]]*root /var/www/html;$' "$DRUPAL_CONF" || { echo "FAIL: root 不存在"; exit 1; }
grep -qE '^[[:space:]]*add_header X-Frame-Options SAMEORIGIN;$' "$DRUPAL_CONF" || { echo "FAIL: X-Frame-Options 不存在"; exit 1; }
grep -qF 'add_header Content-Security-Policy "default-src '\''self'\'';";' "$DRUPAL_CONF" || { echo "FAIL: Content-Security-Policy 不存在"; exit 1; }
echo "sed 目标: OK"

echo "=== 3. 现有 include 保留 ==="
grep -qE '^[[:space:]]*include /etc/nginx/vhost\.d/pre-\*\.conf;$' "$DRUPAL_CONF" || { echo "FAIL: vhost.d/pre 丢失"; exit 1; }
grep -qE '^[[:space:]]*include /etc/nginx/vhost\.d/post-\*\.conf;$' "$DRUPAL_CONF" || { echo "FAIL: vhost.d/post 丢失"; exit 1; }
grep -qE '^[[:space:]]*include /etc/nginx/extra/subdir\.conf;$' "$DRUPAL_CONF" || { echo "FAIL: extra/subdir 丢失"; exit 1; }
echo "现有 include: OK"

echo "=== 4. drupal-maps.conf 迁移 ==="
[ -f "$NEW_MAPS" ] || { echo "FAIL: 新位置文件不存在"; exit 1; }
[ ! -f "$OLD_MAPS" ] || { echo "FAIL: 旧位置文件仍存在"; exit 1; }
echo "drupal-maps 迁移: OK"

echo "=== 5. 锚点位置正确性 ==="
grep -nE 'include sites\.enabled/drupal/' "$DRUPAL_CONF" | head -10
echo "(人工核对：server-pre 应该在第 2 行，server-post 在文件末尾)"

echo ""
echo "ALL_VERIFICATIONS_PASSED"
```

预期：所有检查通过，最终输出 `ALL_VERIFICATIONS_PASSED`。

**Step 2: nginx 语法验证（若本地可用）**

```bash
command -v nginx >/dev/null && {
    # 构造最小化测试用 nginx.conf（需要 php-fpm upstream 等 stub 才能完整测；这里只做基础 include 解析）
    # 实际完整 nginx -t 需要在容器内执行
    echo "本地 nginx 可用，但完整 nginx -t 需在 docker 容器内运行；请用:"
    echo "  docker build ... && docker run --rm <image> nginx -t"
} || echo "本地无 nginx，跳过语法验证（依赖 CI/Docker 构建验证）"
```

预期：给出后续验证建议，无需立即执行。

**Step 3: 查看完整 diff 总结**

```bash
cd /Users/terry/docker/davyinsa/docker-nginx-php
git log --oneline -4
echo "---"
git show --stat HEAD~2..HEAD
```

预期：最近 3 个 commit 分别是 spec、drupal-maps 迁移（cp + rm）、drupal.conf 锚点修改。

**Step 4: 最终提交（若有 .gitkeep 等清理）**

如有任何清理性变更（如 server.conf.d/http/ 目录变空后的处理），单独提交；否则无新提交。

---

## 验收对照（spec → 任务映射）

| Spec 验收项 | 验证任务 |
|------------|---------|
| 1. drupal.conf 含 7 个新锚点 | Task 3 Step 3, Task 4 Step 1 |
| 2. sed 目标字符串原样 | Task 3 Step 4, Task 4 Step 1 |
| 3. vhost.d/pre/post 保留 | Task 3 Step 5, Task 4 Step 1 |
| 4. extra/subdir.conf 保留 | Task 3 Step 5, Task 4 Step 1 |
| 5. 新位置 drupal-maps.conf 内容一致 | Task 1 Step 3 |
| 6. 旧位置 drupal-maps.conf 已删除 | Task 2 Step 1, Task 4 Step 1 |
| 7. nginx -t 通过 | Task 4 Step 2（依赖 Docker 构建） |
| 8. 其他文件未修改 | Task 4 Step 3（git diff 复核） |