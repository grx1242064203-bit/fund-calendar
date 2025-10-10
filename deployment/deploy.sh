#!/bin/bash

# 私募产品开放日管理系统 - 一键部署脚本
# 使用前请确保已配置好服务器环境

set -e  # 遇到错误立即退出

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 日志函数
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# 检查命令是否存在
check_command() {
    if ! command -v $1 &> /dev/null; then
        log_error "$1 未安装，请先安装 $1"
        exit 1
    fi
}

# 前置检查
log_info "检查系统环境..."
check_command node
check_command npm
check_command mysql

# 获取服务器IP
SERVER_IP=$(curl -s http://ipinfo.io/ip || echo "未知")

log_info "服务器IP: $SERVER_IP"

# 创建目录结构
log_info "创建目录结构..."
sudo mkdir -p /opt/private-fund-calendar/{backend,frontend,database,backups,logs}

# 安装Node.js依赖
log_info "安装后端依赖..."
cd /opt/private-fund-calendar/backend
npm install --production

# 配置数据库
log_info "配置数据库..."
read -p "请输入MySQL root密码: " MYSQL_ROOT_PASSWORD

# 创建数据库和用户
sudo mysql -u root -p$MYSQL_ROOT_PASSWORD << EOF
CREATE DATABASE IF NOT EXISTS private_fund_calendar CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
CREATE USER IF NOT EXISTS 'funduser'@'localhost' IDENTIFIED BY 'FundCalendar2025!';
GRANT ALL PRIVILEGES ON private_fund_calendar.* TO 'funduser'@'localhost';
FLUSH PRIVILEGES;
EOF

log_success "数据库配置完成"

# 导入数据库结构
log_info "导入数据库结构..."
sudo mysql -u root -p$MYSQL_ROOT_PASSWORD private_fund_calendar < ../database/schema.sql

# 生成安全密钥
log_info "生成安全密钥..."
JWT_SECRET=$(openssl rand -hex 32)
ENCRYPTION_KEY=$(openssl rand -hex 32)

# 创建环境变量文件
log_info "创建环境变量文件..."
cat > /opt/private-fund-calendar/backend/.env << EOF
# 数据库配置
DB_HOST=localhost
DB_PORT=3306
DB_NAME=private_fund_calendar
DB_USER=funduser
DB_PASSWORD=FundCalendar2025!

# JWT密钥配置 - 生产环境请更换为随机字符串
JWT_SECRET=$(openssl rand -hex 32)
JWT_EXPIRES_IN=7d

# 服务器配置
PORT=4000
NODE_ENV=production

# 跨域配置 - 请替换为实际前端域名
FRONTEND_URL=https://your-frontend-domain.vercel.app

# 加密配置 - 生产环境请更换为随机字符串
ENCRYPTION_KEY=$(openssl rand -hex 32)

# 日志配置
LOG_LEVEL=info
EOF

# 设置 .env 文件权限
chmod 600 /opt/private-fund-calendar/backend/.env

log_success ".env 文件创建完成"

# 更新配置文件（保持兼容性）
log_info "更新后端配置文件..."
cat > /opt/private-fund-calendar/backend/config.js << EOF
// 配置文件
// 加载环境变量
require('dotenv').config();

module.exports = {
  // 数据库配置：优先从环境变量读取，否则用默认值
  database: {
    host: process.env.DB_HOST || 'localhost',
    port: process.env.DB_PORT || 3306,
    database: process.env.DB_NAME || 'private_fund_calendar',
    user: process.env.DB_USER || 'funduser',
    password: process.env.DB_PASSWORD || 'FundCalendar2025!'
  },

  // JWT密钥配置：优先从环境变量读取，否则用默认值
  jwt: {
    secret: process.env.JWT_SECRET || '$JWT_SECRET',
    expiresIn: process.env.JWT_EXPIRES_IN || '7d'
  },

  // 服务器配置：优先从环境变量读取，否则用默认值
  server: {
    port: process.env.PORT || 3001,
    env: process.env.NODE_ENV || 'production'
  },

  // 跨域配置：优先从环境变量读取，否则用默认值
  cors: {
    origin: process.env.FRONTEND_URL || 'https://your-frontend.vercel.app',
    credentials: true
  },

  // 加密配置：优先从环境变量读取，否则用默认值
  encryption: {
    key: process.env.ENCRYPTION_KEY || '$ENCRYPTION_KEY'
  },

  // 日志配置：优先从环境变量读取，否则用默认值
  logging: {
    level: process.env.LOG_LEVEL || 'info'
  }
};
EOF

log_success "配置文件更新完成"

# 安装PM2
log_info "安装PM2..."
if ! command -v pm2 &> /dev/null; then
    npm install -g pm2
fi

# 启动后端服务
log_info "启动后端服务..."
pm2 stop private-fund-backend 2>/dev/null || true
pm2 start /opt/private-fund-calendar/backend/server.js --name "private-fund-backend"
pm2 startup
pm2 save

log_success "后端服务启动完成"

# 配置Nginx
log_info "配置Nginx..."
sudo tee /etc/nginx/sites-available/private-fund << EOF
server {
    listen 80;
    server_name _;

    # API接口代理
    location /api/ {
        proxy_pass http://localhost:3001/api/;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_cache_bypass \$http_upgrade;

        proxy_connect_timeout 60s;
        proxy_send_timeout 60s;
        proxy_read_timeout 60s;
    }

    # 前端静态文件
    location / {
        root /opt/private-fund-calendar/frontend;
        index index.html;
        try_files \$uri \$uri/ /index.html;
    }

    # 安全头
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-XSS-Protection "1; mode=block" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header Referrer-Policy "no-referrer-when-downgrade" always;
    add_header Content-Security-Policy "default-src 'self' http: https: data: blob: 'unsafe-inline'" always;
}
EOF

# 启用Nginx站点
sudo ln -sf /etc/nginx/sites-available/private-fund /etc/nginx/sites-enabled/
sudo rm -f /etc/nginx/sites-enabled/default

# 测试Nginx配置
sudo nginx -t

# 重启Nginx
sudo systemctl restart nginx
sudo systemctl enable nginx

log_success "Nginx配置完成"

# 配置防火墙
log_info "配置防火墙..."
sudo ufw allow 80
sudo ufw allow 4000
sudo ufw allow 443
sudo ufw --force enable

# 创建备份脚本
log_info "创建备份脚本..."
sudo tee /opt/private-fund-calendar/backup.sh << 'EOF'
#!/bin/bash
BACKUP_DIR="/opt/private-fund-calendar/backups"
DATE=$(date +%Y%m%d_%H%M%S)

# 创建备份目录
mkdir -p $BACKUP_DIR

# 备份数据库
mysqldump -u funduser -p'FundCalendar2025!' private_fund_calendar > $BACKUP_DIR/db_backup_$DATE.sql

# 保留最近7天的备份
find $BACKUP_DIR -name "db_backup_*.sql" -type f -mtime +7 -delete

echo "备份完成: $BACKUP_DIR/db_backup_$DATE.sql"
EOF

sudo chmod +x /opt/private-fund-calendar/backup.sh

# 添加定时备份任务
(crontab -l 2>/dev/null || echo "") | grep -v "backup.sh" | crontab -
(crontab -l 2>/dev/null || echo "") | { cat; echo "0 2 * * * /opt/private-fund-calendar/backup.sh"; } | crontab -

log_success "备份配置完成"

# 显示部署信息
log_info "================== 部署完成 =================="
echo -e "${GREEN}后端API地址:${NC} http://$SERVER_IP/api"
echo -e "${GREEN}前端访问地址:${NC} http://$SERVER_IP"
echo -e "${GREEN}管理员账号:${NC} 13800138000"
echo -e "${GREEN}默认密码:${NC} admin123"
echo -e "${YELLOW}重要提示:${NC} 请立即修改默认管理员密码！"
echo ""
echo -e "${BLUE}下一步操作:${NC}"
echo "1. 将前端代码部署到Vercel"
echo "2. 修改前端中的API_BASE_URL为: http://$SERVER_IP/api"
echo "3. 修改默认管理员密码"
echo "4. 配置域名和SSL证书（可选）"
echo ""
echo -e "${GREEN}备份脚本位置:${NC} /opt/private-fund-calendar/backup.sh"
echo -e "${GREEN}日志文件位置:${NC} /opt/private-fund-calendar/logs/"
echo ""
log_success "部署完成！系统已就绪。"
