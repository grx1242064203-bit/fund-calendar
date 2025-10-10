# 生产环境部署检查清单

## 📋 部署前检查清单

### 1. 域名和网络配置
- [ ] 域名 `api.product-gh.cn` 已解析到阿里云服务器公网IP `8.152.0.3`
- [ ] 阿里云安全组已开放端口：80、4000、443、22
- [ ] 前端域名已配置（Vercel自动分配）

### 2. 数据库配置
- [ ] MySQL服务正常运行
- [ ] 数据库 `private_fund_calendar` 已创建
- [ ] 数据库用户 `funduser` 已创建并授权
- [ ] 数据库密码已设置（非默认密码）

### 3. 后端配置
- [ ] Node.js 16+ 已安装
- [ ] PM2 已安装
- [ ] 后端代码已上传到服务器 `/opt/private-fund-calendar/backend/`
- [ ] 依赖已安装：`npm install --production`
- [ ] `.env` 文件已创建并配置正确：
  ```env
  DB_HOST=localhost
  DB_PORT=3306
  DB_NAME=private_fund_calendar
  DB_USER=funduser
  DB_PASSWORD=你的密码
  PORT=4000
  JWT_SECRET=你的随机密钥
  ENCRYPTION_KEY=你的随机密钥
  FRONTEND_URL=https://你的前端域名.vercel.app
  ```

### 4. 前端配置
- [ ] 前端代码中的 `API_BASE_URL` 已更新为：`http://api.product-gh.cn:4000/api`
- [ ] 前端已部署到Vercel

### 5. 安全配置
- [ ] 防火墙已配置并启用
- [ ] 所有默认密码已修改
- [ ] JWT密钥和加密密钥已随机生成
- [ ] `.env` 文件权限设置为600

## 🚀 部署步骤

### 1. 后端部署
```bash
# 上传代码
scp -r ./backend root@8.152.0.3:/opt/private-fund-calendar/

# 连接服务器
ssh root@8.152.0.3

# 安装依赖
cd /opt/private-fund-calendar/backend
npm install --production

# 创建并配置 .env 文件
cp env.template .env
nano .env  # 编辑配置

# 启动服务
pm2 start server.js --name "private-fund-backend"
pm2 startup
pm2 save
```

### 2. 前端部署
```bash
# 前端已部署到Vercel
# 确保API_BASE_URL已正确配置
```

### 3. 验证部署
```bash
# 测试后端API
curl http://api.product-gh.cn:4000/api/products

# 测试前端访问
# 访问前端域名，确认可以正常登录和使用
```

## 🔧 生产环境配置示例

### 阿里云ECS配置
- **实例规格**: 2核4G或更高
- **操作系统**: Ubuntu 20.04 LTS
- **安全组规则**:
  - 入方向: TCP 80 (HTTP)
  - 入方向: TCP 4000 (后端API)
  - 入方向: TCP 443 (HTTPS)
  - 入方向: TCP 22 (SSH)

### MySQL配置
```sql
CREATE DATABASE private_fund_calendar CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
CREATE USER 'funduser'@'localhost' IDENTIFIED BY '你的强密码';
GRANT ALL PRIVILEGES ON private_fund_calendar.* TO 'funduser'@'localhost';
FLUSH PRIVILEGES;
```

### Nginx配置 (可选)
```nginx
server {
    listen 80;
    server_name api.product-gh.cn;

    location / {
        proxy_pass http://localhost:4000;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}
```

## 🔒 安全建议

1. **更改所有默认密码**
2. **定期更新系统和软件包**
3. **配置防火墙，只开放必要端口**
4. **启用HTTPS（推荐）**
5. **定期备份数据库和代码**
6. **监控系统日志**
7. **限制数据库用户权限**

## 📊 监控和维护

### 日志监控
```bash
# 查看后端日志
pm2 logs private-fund-backend

# 查看系统日志
tail -f /var/log/nginx/access.log
```

### 性能监控
```bash
# 安装监控工具
apt install htop iotop

# 查看系统资源
htop
```

### 备份策略
- **数据库备份**: 每天凌晨2点自动备份
- **代码备份**: 使用Git版本控制
- **配置备份**: 备份.env文件（不包含敏感信息）

## 🚨 故障排除

### 常见问题

1. **数据库连接失败**:
   - 检查MySQL服务状态
   - 验证数据库配置
   - 检查防火墙设置

2. **后端服务无法启动**:
   - 检查端口4000是否被占用
   - 查看PM2日志
   - 检查Node.js版本

3. **前端无法访问API**:
   - 检查跨域配置
   - 确认API地址正确
   - 检查防火墙设置

4. **域名解析问题**:
   - 检查DNS配置
   - 确认域名指向正确IP

## 📞 技术支持

部署完成后，如遇到问题，请：
1. 查看相关日志文件
2. 检查配置文件
3. 确认网络连通性
4. 参考本文档

---

**部署完成标准**:
- [ ] 后端API服务正常运行（端口4000）
- [ ] 前端可以正常访问后端API
- [ ] 用户可以正常注册和登录
- [ ] 所有功能模块正常工作
- [ ] 系统安全配置正确
