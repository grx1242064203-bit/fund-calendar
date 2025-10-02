# 私募产品开放日管理系统 - 后端服务

这是基于 Node.js + Express + MySQL 的后端服务，提供完整的API接口用于管理私募产品开放日信息。

## 技术栈

- **运行环境**: Node.js 16+
- **Web框架**: Express.js
- **数据库**: MySQL 8.0+
- **认证**: JWT (JSON Web Token)
- **加密**: bcryptjs (密码哈希) + AES-256-CBC (敏感数据加密)
- **安全**: Helmet (安全头) + CORS (跨域) + Rate Limiting (速率限制)

## 安装依赖

```bash
cd backend
npm install
```

## 环境变量配置

1. 创建环境变量文件：
```bash
# 复制模板文件
cp env.template .env
```

2. 编辑 `.env` 文件，填入实际配置：

```env
# 数据库配置
DB_HOST=your-db-host
DB_PORT=3306
DB_NAME=private_fund_calendar
DB_USER=your-db-user
DB_PASSWORD=your-db-password

# JWT密钥配置 - 请生成随机字符串
JWT_SECRET=your-jwt-secret-key-here
JWT_EXPIRES_IN=7d

# 服务器配置
PORT=3001
NODE_ENV=production

# 跨域配置
FRONTEND_URL=https://your-frontend.vercel.app

# 加密配置
ENCRYPTION_KEY=your-32-character-encryption-key

# 日志配置
LOG_LEVEL=info
```

### 创建 .env 文件

由于安全原因，`.env` 文件不会包含在代码仓库中。有两种方式创建：

#### 方式一：使用生成脚本（推荐）

```bash
# 生成安全的密钥配置
npm run generate-env

# 按照提示复制生成的配置内容
# 在项目根目录创建 .env 文件
touch .env

# 将生成的配置粘贴到 .env 文件中
# 根据实际情况修改数据库密码和前端域名
```

#### 方式二：手动创建

```bash
# 在项目根目录下创建 .env 文件
cd /path/to/private-fund-calendar/backend
touch .env
```

然后编辑 `.env` 文件，添加以下内容并填入实际配置值：

```env
# 数据库配置
DB_HOST=localhost
DB_PORT=3306
DB_NAME=private_fund_calendar
DB_USER=root
DB_PASSWORD=你的数据库密码

# JWT密钥配置 - 请生成随机字符串
JWT_SECRET=你的复杂JWT密钥字符串
JWT_EXPIRES_IN=7d

# 服务器配置
PORT=3001
NODE_ENV=production

# 跨域配置
FRONTEND_URL=https://你的前端域名.vercel.app

# 加密配置
ENCRYPTION_KEY=你的32位加密密钥

# 日志配置
LOG_LEVEL=info
```

### 安全注意事项

- **永远不要将 `.env` 文件提交到Git仓库**
- **使用强密码和随机密钥**
- **定期更换敏感信息**
- **根据需要设置适当的文件权限**

## 数据库初始化

1. 创建数据库：
```sql
CREATE DATABASE private_fund_calendar CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
```

2. 导入数据库结构：
```bash
mysql -u your_db_user -p private_fund_calendar < ../database/schema.sql
```

3. 验证数据库连接：
```bash
npm run dev
```
如果看到"数据库连接成功"表示配置正确。

## 启动服务

### 开发模式
```bash
npm run dev
```

### 生产模式
```bash
npm start
```

服务将在指定端口启动（默认3001）。

## API文档

### 认证相关

#### 用户注册
- **接口**: `POST /api/auth/register`
- **权限**: 公开
- **请求体**:
```json
{
  "phone": "13800138000",
  "password": "password123",
  "realName": "张三",
  "email": "zhangsan@example.com"
}
```

#### 用户登录
- **接口**: `POST /api/auth/login`
- **权限**: 公开
- **请求体**:
```json
{
  "phone": "13800138000",
  "password": "password123"
}
```
- **响应**:
```json
{
  "message": "登录成功",
  "token": "jwt_token_here",
  "user": {
    "id": 1,
    "phone": "13800138000",
    "role": "user",
    "realName": "张三"
  }
}
```

#### 获取用户信息
- **接口**: `GET /api/auth/me`
- **权限**: 需要认证
- **请求头**: `Authorization: Bearer <token>`

### 产品管理

#### 获取产品列表
- **接口**: `GET /api/products`
- **权限**: 需要认证
- **查询参数**:
  - `page`: 页码 (默认1)
  - `limit`: 每页数量 (默认20)
  - `search`: 搜索关键词

#### 获取产品详情
- **接口**: `GET /api/products/:id`
- **权限**: 需要认证

#### 创建/更新产品
- **接口**: `POST /api/products`
- **权限**: 管理员
- **请求体**:
```json
{
  "productCode": "HF001",
  "productName": "华凡启明2号",
  "description": "产品描述",
  "openDates": [
    {
      "openType": "both",
      "openDate": "2025-10-15",
      "periodStartDays": 3,
      "periodEndDays": 1
    }
  ],
  "reservationPeriods": [
    {
      "openType": "both",
      "periodStartDate": "2025-10-12",
      "periodEndDate": "2025-10-14"
    }
  ]
}
```

### 休市日管理

#### 获取休市日列表
- **接口**: `GET /api/holidays`
- **权限**: 需要认证
- **查询参数**:
  - `year`: 年份 (默认当前年)

#### 添加休市日
- **接口**: `POST /api/holidays`
- **权限**: 管理员
- **请求体**:
```json
{
  "holidayDate": "2025-12-25",
  "holidayName": "圣诞节",
  "holidayType": "national"
}
```

### 日历数据

#### 获取日历数据
- **接口**: `GET /api/calendar/:year/:month`
- **权限**: 需要认证
- **示例**: `GET /api/calendar/2025/10`

## 部署说明

### 阿里云ECS部署

1. **安装Node.js**:
```bash
# 使用nvm安装Node.js 16+
curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.0/install.sh | bash
source ~/.bashrc
nvm install 16
nvm use 16
```

2. **安装PM2** (生产环境进程管理):
```bash
npm install -g pm2
```

3. **上传代码到服务器**:
```bash
# 假设使用scp上传
scp -r ./backend root@your-server-ip:/opt/private-fund-calendar/
```

4. **安装依赖并启动**:
```bash
cd /opt/private-fund-calendar/backend
npm install --production
pm2 start server.js --name "private-fund-backend"
pm2 startup
pm2 save
```

5. **配置反向代理** (Nginx):
```nginx
server {
    listen 80;
    server_name your-domain.com;

    location / {
        proxy_pass http://localhost:3001;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_cache_bypass $http_upgrade;
    }
}
```

6. **设置防火墙**:
```bash
# 开放80端口
firewall-cmd --permanent --add-port=80/tcp
firewall-cmd --reload
```

## 安全注意事项

1. **更改默认配置**:
   - 修改数据库密码
   - 修改JWT密钥
   - 修改加密密钥

2. **HTTPS配置**:
   - 在生产环境中启用HTTPS
   - 配置SSL证书

3. **数据库安全**:
   - 不要使用root用户
   - 创建专用数据库用户
   - 限制数据库访问IP

4. **日志监控**:
   - 监控错误日志
   - 设置日志轮转
   - 定期备份日志

## 故障排除

### 常见问题

1. **数据库连接失败**:
   - 检查数据库服务是否启动
   - 验证数据库配置信息
   - 检查防火墙设置

2. **端口占用**:
   - 检查3001端口是否被占用
   - 修改配置文件中的端口号

3. **依赖安装失败**:
   - 清理npm缓存: `npm cache clean --force`
   - 删除node_modules重新安装: `rm -rf node_modules && npm install`

### 日志查看

```bash
# 查看PM2日志
pm2 logs private-fund-backend

# 查看系统日志
tail -f /var/log/nginx/access.log
tail -f /var/log/nginx/error.log
```

## 更新说明

当需要更新后端代码时：

1. 备份数据库
2. 停止当前服务: `pm2 stop private-fund-backend`
3. 上传新代码
4. 安装依赖: `npm install --production`
5. 启动服务: `pm2 start server.js --name "private-fund-backend"`
6. 验证服务状态: `pm2 status`

## 性能优化建议

1. **数据库优化**:
   - 添加适当的数据库索引
   - 定期清理无用数据
   - 监控慢查询

2. **应用优化**:
   - 启用Redis缓存(可选)
   - 使用CDN加速静态资源
   - 实施数据库连接池

3. **监控建议**:
   - 使用PM2监控面板
   - 设置关键指标告警
   - 定期性能测试
