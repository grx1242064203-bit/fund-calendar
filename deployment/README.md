# 私募产品开放日管理系统 - 部署指南

本指南提供了完整的系统部署说明，包括前端（Vercel）、后端（阿里云ECS）和数据库（MySQL）的部署步骤。

## 系统架构

```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   Vercel前端    │    │   阿里云ECS     │    │      MySQL      │
│   (用户界面)    │◄──►│   (API服务)     │◄──►│   (数据库)      │
└─────────────────┘    └─────────────────┘    └─────────────────┘
```

## 1. 数据库部署

### 1.1 MySQL数据库准备

1. **安装MySQL** (如果还没有安装):
```bash
# Ubuntu/Debian
sudo apt update
sudo apt install mysql-server

# CentOS/RHEL
sudo yum install mysql-server
```

2. **启动MySQL服务**:
```bash
sudo systemctl start mysql
sudo systemctl enable mysql
```

3. **设置MySQL root密码**:
```bash
sudo mysql_secure_installation
```

4. **创建数据库和用户**:
```bash
mysql -u root -p

# 创建数据库
CREATE DATABASE private_fund_calendar CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

# 创建专用用户
CREATE USER 'funduser'@'%' IDENTIFIED BY 'your_strong_password';
GRANT ALL PRIVILEGES ON private_fund_calendar.* TO 'funduser'@'%';
FLUSH PRIVILEGES;

# 退出MySQL
EXIT;
```

5. **导入数据库结构**:
```bash
mysql -u funduser -p private_fund_calendar < database/schema.sql
```

## 2. 后端部署（阿里云ECS）

### 2.1 服务器准备

1. **购买阿里云ECS**:
   - 选择合适的地域和规格（建议2核4G以上）
   - 选择Ubuntu 20.04或CentOS 8操作系统
   - 配置安全组规则：开放80端口（HTTP）、4000端口（后端API）和22端口（SSH）

2. **连接到服务器**:
```bash
ssh root@your-server-ip
```

### 2.2 安装Node.js

```bash
# 更新系统包
apt update && apt upgrade -y

# 安装curl（如果没有）
apt install curl -y

# 安装Node.js 16.x
curl -fsSL https://deb.nodesource.com/setup_16.x | bash -
apt install nodejs -y

# 验证安装
node --version
npm --version
```

### 2.3 安装PM2（生产环境进程管理）

```bash
npm install -g pm2
```

### 2.4 部署后端代码

1. **上传代码到服务器**:
```bash
# 在本地打包后端代码
cd backend
npm install --production
cd ..
tar -czf backend.tar.gz backend/

# 上传到服务器（假设服务器IP为1.2.3.4）
scp backend.tar.gz root@1.2.3.4:/opt/

# 在服务器上解压
ssh root@1.2.3.4
cd /opt
tar -xzf backend.tar.gz
cd backend
```

2. **配置后端**:
```bash
# 复制配置文件
cp config.example.js config.js

# 编辑配置文件
nano config.js
```

填入实际配置：
```javascript
module.exports = {
  database: {
    host: 'localhost', // 或你的MySQL服务器地址
    port: 3306,
    database: 'private_fund_calendar',
    user: 'funduser',
    password: 'your_strong_password'
  },

  jwt: {
    secret: 'your_jwt_secret_key_here', // 生成一个随机的32位字符串
    expiresIn: '7d'
  },

  server: {
    port: 3001,
    env: 'production'
  },

  cors: {
    origin: 'https://your-frontend.vercel.app', // 替换为实际的前端域名
    credentials: true
  },

  encryption: {
    key: 'your_32_character_encryption_key' // 必须是32位字符
  },

  logging: {
    level: 'info'
  }
};
```

3. **启动后端服务**:
```bash
# 启动服务
pm2 start server.js --name "private-fund-backend"

# 设置开机自启动
pm2 startup
pm2 save

# 查看状态
pm2 status
pm2 logs private-fund-backend
```

### 2.5 配置Nginx反向代理

```bash
# 安装Nginx
apt install nginx -y

# 编辑配置文件
nano /etc/nginx/sites-available/private-fund
```

添加以下配置：
```nginx
server {
    listen 80;
    server_name your-domain.com; # 替换为你的域名

    # API接口代理
    location /api/ {
        proxy_pass http://localhost:3001/api/;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_cache_bypass $http_upgrade;

        # 增加超时设置
        proxy_connect_timeout 60s;
        proxy_send_timeout 60s;
        proxy_read_timeout 60s;
    }

    # 前端静态文件（如果需要）
    location / {
        root /var/www/html;
        index index.html;
        try_files $uri $uri/ /index.html;
    }

    # 安全头
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-XSS-Protection "1; mode=block" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header Referrer-Policy "no-referrer-when-downgrade" always;
    add_header Content-Security-Policy "default-src 'self' http: https: data: blob: 'unsafe-inline'" always;
}
```

```bash
# 启用站点
ln -s /etc/nginx/sites-available/private-fund /etc/nginx/sites-enabled/

# 删除默认站点
rm /etc/nginx/sites-enabled/default

# 测试配置
nginx -t

# 重启Nginx
systemctl restart nginx
systemctl enable nginx
```

### 2.6 配置防火墙

```bash
# 开放端口
ufw allow 80
ufw allow 4000
ufw allow 443

# 启用防火墙
ufw enable

# 查看状态
ufw status
```

## 3. 前端部署（Vercel）

### 3.1 准备前端代码

1. **修改API地址**:
编辑 `frontend/index.html` 中的 `API_BASE_URL`：
```javascript
const API_BASE_URL = 'https://your-api-domain.com/api';
```

2. **打包前端代码** (可选，如果需要静态部署):
```bash
# 如果需要打包，可以使用webpack等工具
# 或者直接部署HTML文件到Vercel
```

### 3.2 Vercel部署

1. **安装Vercel CLI**:
```bash
npm install -g vercel
```

2. **登录Vercel**:
```bash
vercel login
```

3. **部署前端**:
```bash
# 进入前端目录
cd frontend

# 部署（首次部署）
vercel --prod

# 后续更新
vercel --prod
```

或者通过GitHub集成自动部署：

1. 将代码推送到GitHub仓库
2. 在Vercel中连接GitHub仓库
3. 设置自动部署

### 3.3 Vercel配置

在Vercel控制台中：

1. **环境变量**:
   - 不需要设置环境变量，前端是纯静态的

2. **域名配置**:
   - 自定义域名（如果有）
   - SSL证书会自动配置

3. **构建设置**:
   - 构建命令：不需要（纯HTML）
   - 输出目录：不需要指定
   - 安装命令：不需要

## 4. 域名和SSL配置

### 4.1 域名解析

1. **购买域名** (如果还没有)
2. **添加DNS记录**:
   - A记录指向阿里云ECS公网IP
   - 或CNAME记录指向Vercel域名

### 4.2 SSL证书

- **阿里云ECS**: 使用Let's Encrypt免费证书或阿里云SSL证书
- **Vercel**: 自动提供免费SSL证书

## 5. 系统初始化

### 5.1 创建管理员用户

系统已预设管理员账号：
- 手机号：13800138000
- 密码：admin123

**重要**：部署后立即修改默认密码！

### 5.2 导入初始数据

如果有初始产品数据，可以通过Excel导入功能添加。

### 5.3 系统配置

登录管理员账号后，可以：
- 修改个人信息
- 添加其他管理员用户
- 管理休市日
- 添加产品信息

## 6. 监控和维护

### 6.1 日志监控

```bash
# 查看后端日志
pm2 logs private-fund-backend

# 查看Nginx日志
tail -f /var/log/nginx/access.log
tail -f /var/log/nginx/error.log

# 查看系统日志
journalctl -u mysql -f
```

### 6.2 性能监控

```bash
# 安装监控工具
apt install htop iotop

# 查看系统资源使用
htop

# 查看磁盘使用情况
df -h

# 查看内存使用情况
free -h
```

### 6.3 备份策略

1. **数据库备份**:
```bash
# 创建备份脚本
nano /opt/backup-db.sh
```

```bash
#!/bin/bash
BACKUP_DIR="/opt/backups"
DATE=$(date +%Y%m%d_%H%M%S)
mysqldump -u funduser -p'your_password' private_fund_calendar > $BACKUP_DIR/db_backup_$DATE.sql
find $BACKUP_DIR -name "db_backup_*.sql" -type f -mtime +7 -delete
```

```bash
# 设置执行权限并添加定时任务
chmod +x /opt/backup-db.sh
echo "0 2 * * * /opt/backup-db.sh" | crontab -
```

2. **代码备份**:
```bash
# 使用Git仓库管理代码版本
# 或者定期打包备份
```

### 6.4 更新部署

```bash
# 更新后端代码
cd /opt/backend
pm2 stop private-fund-backend

# 备份当前代码
cp -r /opt/backend /opt/backend.backup.$(date +%Y%m%d_%H%M%S)

# 上传新代码并安装依赖
npm install --production

# 启动服务
pm2 start server.js --name "private-fund-backend"
```

## 7. 故障排除

### 7.1 常见问题

1. **数据库连接失败**:
   - 检查MySQL服务状态: `systemctl status mysql`
   - 检查数据库配置是否正确
   - 检查防火墙设置

2. **后端服务无法启动**:
   - 检查端口4000是否被占用: `netstat -tlnp | grep 4000`
   - 检查Node.js和npm版本
   - 查看PM2日志: `pm2 logs`

3. **前端无法访问API**:
   - 检查跨域配置
   - 检查防火墙设置
   - 确认API地址正确

4. **静态资源无法加载**:
   - 检查Nginx配置
   - 检查文件权限

### 7.2 调试技巧

1. **测试数据库连接**:
```bash
mysql -u funduser -p -h localhost private_fund_calendar -e "SELECT 1"
```

2. **测试API接口**:
```bash
curl http://localhost:3001/api/products
```

3. **检查网络连通性**:
```bash
# 测试域名解析
nslookup your-domain.com

# 测试端口连通性
telnet your-domain.com 80
telnet your-domain.com 4000
```

## 8. 安全建议

1. **更改所有默认密码**
2. **定期更新系统和软件包**
3. **配置防火墙，只开放必要端口**
4. **启用HTTPS**
5. **定期备份数据**
6. **监控日志文件**
7. **限制数据库用户权限**
8. **使用强密码和密钥**

## 9. 扩展建议

1. **Redis缓存**: 提升性能
2. **Docker容器化**: 简化部署
3. **CDN加速**: 提升全球访问速度
4. **监控告警**: 及时发现问题
5. **负载均衡**: 支持高并发

## 10. 技术支持

如果遇到部署问题，请：
1. 查看日志文件
2. 检查配置文件
3. 确认网络连通性
4. 参考官方文档

---

**部署完成检查清单**:
- [ ] 数据库已创建并初始化
- [ ] 后端服务正常运行
- [ ] Nginx反向代理配置正确
- [ ] 前端部署到Vercel
- [ ] 域名和SSL证书配置
- [ ] 默认管理员密码已修改
- [ ] 防火墙配置正确
- [ ] 备份策略已设置
