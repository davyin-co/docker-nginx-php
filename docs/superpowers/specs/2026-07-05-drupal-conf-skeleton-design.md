# drupal.conf 骨架化重构设计

**日期:** 2026-07-05
**状态:** 已批准
**作者:** brainstorming session

## 背景

`install/etc/nginx/sites.available/drupal.conf` 当前是一个 178 行的单体配置文件，将 server 级别指令和所有 Drupal 专属 location 块全部内联。nfrastack 上游默认站点（`/etc/nginx/sites.enabled/default.conf`）采用模块化骨架结构，通过七个 include 锚点（`server-pre`、`server-begin`、`location-pre`、`location`、`location-post`、`server-end`、`server-post`）让运维可以按需插入自定义配置片段而不必修改站点主配置。

当前 drupal.conf 仅提供 `vhost.d/pre-*.conf` 和 `vhost.d/post-*.conf` 两个粗粒度锚点，无法在不修改主文件的情况下扩展 server 级别指令或插入自定义 location。

## 目标

1. 将 drupal.conf 改造为与上游 `default.conf` 一致的七锚点骨架结构，**不改变现有指令、不破坏 init script 的 sed 替换逻辑**，仅为未来模块化演进预留标准接口。
2. 将 `install/etc/nginx/server.conf.d/http/drupal-maps.conf`（http 级 `map` 指令）迁移到 `install/etc/nginx/sites.enabled/drupal/server-pre/drupal-maps.conf`，使所有 Drupal 专属 nginx 配置统一在 `sites.enabled/drupal/` 树下。

## 非目标（YAGNI）

- 不拆分现有 location 块到独立文件
- 不创建除 `server-pre/` 外的其他 sites.enabled/drupal 子目录
- 不修改 `install/container/init/init.d/40-drupal`
- 不修改 `extra/subdir.conf`、`vhost.d/`
- 不调整现有 location 块的顺序或内容

## 设计

### 文件: `install/etc/nginx/sites.available/drupal.conf`

在恰当位置插入七个 include 锚点，所有现有指令内容原样保留。

### 锚点位置表

| 锚点 | 路径 | 插入位置 | 上下文 |
|------|------|---------|--------|
| `server-pre` | `sites.enabled/drupal/server-pre/*.conf` | 文件开头、server 块之前 | server 块外 |
| `server-begin` | `sites.enabled/drupal/server-begin/*.conf` | `listen 80;` 和 `root /var/www/html;` 之后、首个 `add_header` 之前 | server 级别指令扩展点 |
| `location-pre` | `sites.enabled/drupal/location-pre/*.conf` | 现有 `include /etc/nginx/vhost.d/pre-*.conf;` 之前 | location 块之前的 server 级别扩展点 |
| `location` | `sites.enabled/drupal/location/*.conf` | 现有 `location ~* robots.txt|... { return 404; }` 之前（即第一个 location 块之前） | 额外 location 块插入点 |
| `location-post` | `sites.enabled/drupal/location-post/*.conf` | 所有 location 块之后、方法检查之前 | location 块之后的 server 级别扩展点 |
| `server-end` | `sites.enabled/drupal/server-end/*.conf` | 现有 `include /etc/nginx/vhost.d/post-*.conf;` 之前 | server 块末尾扩展点 |
| `server-post` | `sites.enabled/drupal/server-post/*.conf` | server 块闭合 `}` 之后 | server 块外 |

### 完整结构

```nginx
## Reference: https://www.nginx.com/resources/wiki/start/topics/recipes/drupal/
include sites.enabled/drupal/server-pre/*.conf;

server {
    listen 80;
    root /var/www/html;

    include sites.enabled/drupal/server-begin/*.conf;

    add_header X-Frame-Options SAMEORIGIN;
    add_header Content-Security-Policy "default-src 'self';";
    add_header X-Content-Type-Options nosniff;
    add_header X-XSS-Protection "1; mode=block";
    add_header X-Download-Options noopen;
    add_header X-Permitted-Cross-Domain-Policies none;
    add_header Referrer-Policy no-referrer-when-downgrade;
    add_header Strict-Transport-Security "max-age=0";

    include sites.enabled/drupal/location-pre/*.conf;
    include /etc/nginx/vhost.d/pre-*.conf;

    ## For Security.
    location ~* robots.txt|README.txt|... { return 404; }
    location ~* /sites/[^/]+/[^/]+\.php$ { deny all; return 404; }
    location ~* \.(js\.map|...) { return 404; }
    location @rewrite_subdir { rewrite ^ /index.php; }
    include /etc/nginx/extra/subdir.conf;
    location = /favicon.ico { log_not_found off; access_log off; }
    location ~ \..*/.*\.php$ { return 403; }
    location ~ ^/sites/.*/private/ { return 403; }
    location ~* ^/.well-known/ { allow all; }
    location ~ (^|/)\. { return 403; }

    include sites.enabled/drupal/location/*.conf;

    location = / { try_files $uri $drupal_boost_try_homepage_final /index.php/?$query_string; }
    location / { try_files $uri $drupal_boost_try_final /index.php?$query_string; }
    location @rewrite { rewrite ^/(.*)$ /index.php?q=$1; }
    location ~ /vendor/.*\.php$ { deny all; return 404; }
    location ~ ^(?!/core/modules/statistics/statistics\.php$).+/.+/.+/.+\.php$ { deny all; return 404; }
    location ~ '\.php$|^/update.php' { ... fastcgi ... }
    location ~ ^/sites/.*/files/styles/ { try_files $uri @rewrite; }
    location ~ ^/sites/.*/files/ { ... }
    location ~ ^/sites/.*/files/styles/.*/public/ { try_files $uri @rewrite; }
    location ~* ^(?!/system/files).*\.(js|css|...) { ... }
    location @nobots { ... }
    location ~* files/advagg_(?:css|js)/ { ... }
    location ~* \.(?:js|css|...) { ... }
    location ~* \.(otf|eot|ttf|woff) { ... }
    location ~* \.mjs$ { types { ... } }

    include sites.enabled/drupal/location-post/*.conf;

    if ( $request_method !~ ^(GET|POST|PUT|PATCH|DELETE|HEAD)$ ) { return 405; }

    include sites.enabled/drupal/server-end/*.conf;
    include /etc/nginx/vhost.d/post-*.conf;
}

include sites.enabled/drupal/server-post/*.conf;
```

（注：上述结构中 `...` 代表原文件中对应行的完整内容，详见 `install/etc/nginx/sites.available/drupal.conf` 当前内容。）

## 兼容性分析

### init script 兼容（关键）

`install/container/init/init.d/40-drupal` 通过 `sed -i` 替换以下四个目标字符串：

| sed 目标 | 在新 drupal.conf 中的位置 |
|---------|------------------------|
| `listen 80;` | 第 5 行（`server { listen 80;`），原样保留 |
| `root /var/www/html;` | 第 6 行，原样保留 |
| `add_header X-Frame-Options SAMEORIGIN;` | `server-begin` 锚点之后，原样保留 |
| `add_header Content-Security-Policy "default-src 'self'";` | 同上区域，原样保留 |

所有 sed 目标字符串**原样保留**，sed 操作继续有效。

### 现有 include 兼容

- `include /etc/nginx/vhost.d/pre-*.conf;` —— 保留，在 `location-pre` 锚点之后
- `include /etc/nginx/vhost.d/post-*.conf;` —— 保留，在 `server-end` 锚点之后
- `include /etc/nginx/extra/subdir.conf;` —— 保留，位置不变
- `map` 配置 —— 迁移后由 `sites.enabled/drupal/server-pre/drupal-maps.conf` 通过 drupal.conf 的 `server-pre` 锚点加载，http 上下文（server 块外）有效

### drupal-maps.conf 迁移

`install/etc/nginx/server.conf.d/http/drupal-maps.conf` 的 `map` 指令是 http 级别指令，**必须在 http {} 块内、server {} 块外才有效**。这正好对应 default.conf 模式中 `server-pre` 锚点的位置（http 块内、server 块外）。

迁移路径：
- 源文件：`install/etc/nginx/server.conf.d/http/drupal-maps.conf`
- 目标文件：`install/etc/nginx/sites.enabled/drupal/server-pre/drupal-maps.conf`（目录新建）
- 内容：原样复制
- 上游 nginx.conf 的 `include /etc/nginx/server.conf.d/http/*.conf;` 在原文件删除后变为空 glob，无害

迁移后所有 Drupal 相关 nginx 配置集中在 `sites.enabled/drupal/` 树下：
```
sites.enabled/drupal/server-pre/drupal-maps.conf   <-- http 级 map
sites.enabled/drupal.conf                          <-- server 级主配置（含其余 6 个锚点）
```

### 运行时行为

新增的 7 个 `include sites.enabled/drupal/*/*.conf;` 在运行时：
- `server-pre/*.conf` —— 至少 1 个匹配文件（drupal-maps.conf），加载 map 指令
- 其余 6 个目录 —— 空目录，nginx 跳过该 include，无警告或错误

### 行为差异

**零行为差异。** 现有所有指令保持原顺序、原位置、原内容。`map` 配置加载时机与原方案等价（都在 http 块初始化阶段加载）。nginx 配置解析结果与重构前完全一致。

## 风险与缓解

| 风险 | 缓解措施 |
|------|---------|
| sed 替换目标字符串被破坏 | 设计已确认目标行原样保留 |
| include 通配符在空目录下报错 | nginx 对空 glob 静默处理，无报错 |
| `map` 指令放在 server 块外加载位置错误 | `server-pre` 锚点位于 http 块内、server 块外，与 map 指令要求的 http 上下文一致 |
| 删除 `server.conf.d/http/drupal-maps.conf` 后上游 nginx.conf 行为异常 | 上游 base image 的 `include /etc/nginx/server.conf.d/http/*.conf;` 对空 glob 静默处理 |
| 未来模块化迁移时的兼容性 | 锚点命名与位置严格对齐上游 default.conf |

## 验收标准

1. `install/etc/nginx/sites.available/drupal.conf` 中精确出现 7 个新的 `include sites.enabled/drupal/*/*.conf;` 行
2. 现有所有指令行（特别是 `listen 80;`、`root /var/www/html;`、`add_header X-Frame-Options`、`add_header Content-Security-Policy`）保持原样
3. `include /etc/nginx/vhost.d/pre-*.conf;` 和 `include /etc/nginx/vhost.d/post-*.conf;` 保留
4. `include /etc/nginx/extra/subdir.conf;` 位置不变
5. `install/etc/nginx/sites.enabled/drupal/server-pre/drupal-maps.conf` 内容与原 `install/etc/nginx/server.conf.d/http/drupal-maps.conf` 完全一致
6. 原 `install/etc/nginx/server.conf.d/http/drupal-maps.conf` 文件已删除
7. 用 `nginx -t` 语法验证通过（如本机有 nginx 可用）
8. 不修改其他任何文件（init script、extra/subdir.conf、vhost.d/ 保持原样）

## 实施步骤（高层）

1. 创建目录 `install/etc/nginx/sites.enabled/drupal/server-pre/`
2. 将 `install/etc/nginx/server.conf.d/http/drupal-maps.conf` 复制到 `install/etc/nginx/sites.enabled/drupal/server-pre/drupal-maps.conf`
3. 删除原 `install/etc/nginx/server.conf.d/http/drupal-maps.conf`（如目录变空可保留目录壳或保留 .gitkeep）
4. 修改 `install/etc/nginx/sites.available/drupal.conf`：在 7 个指定位置插入 include 锚点
5. 验证：
   - 锚点数量 = 7
   - sed 目标字符串原样存在
   - 现有 include 行保留
   - drupal-maps.conf 内容字节级一致
   - 文件总行数变化仅来自新增的 7 行锚点（从 178 行增加到约 185 行）

## 未来演进路径

本次重构为完全模块化迁移铺路。后续如需完全拆分，仅需：
- 创建 `install/etc/nginx/sites.enabled/drupal/{server-begin,location-pre,location,location-post,server-end,server-post}/` 目录结构
- 将 drupal.conf 中对应区域的指令块迁移到独立文件
- 重写 `40-drupal` init script，使用模板渲染（如 `envsubst`）替代 `sed -i`

本次不在演进范围内。