#!/bin/bash
# User Data Script for Odoo Installation
# Enterprise-grade setup with security and monitoring

set -e

# Variables from Terraform
DB_ENDPOINT="${db_endpoint}"
DB_NAME="${db_name}"
DB_USERNAME="${db_username}"
DB_PASSWORD="${db_password}"
BACKUP_BUCKET="${backup_bucket}"
MEDIA_BUCKET="${media_bucket}"
PROJECT_NAME="${project_name}"
ENVIRONMENT="${environment}"

# Logging setup
exec > >(tee /var/log/user-data.log|logger -t user-data -s 2>/dev/console) 2>&1
echo "Starting Odoo installation at $(date)"

# Update system
apt-get update
apt-get upgrade -y

# Install required packages
apt-get install -y \
    python3 \
    python3-pip \
    python3-dev \
    python3-venv \
    postgresql-client \
    nginx \
    supervisor \
    git \
    curl \
    wget \
    unzip \
    awscli \
    amazon-cloudwatch-agent \
    htop \
    vim \
    fail2ban \
    ufw \
    logrotate

# Install Node.js and npm for Odoo frontend
curl -fsSL https://deb.nodesource.com/setup_18.x | bash -
apt-get install -y nodejs

# Install wkhtmltopdf for PDF generation
wget https://github.com/wkhtmltopdf/packaging/releases/download/0.12.6.1-2/wkhtmltox_0.12.6.1-2.jammy_amd64.deb
dpkg -i wkhtmltox_0.12.6.1-2.jammy_amd64.deb || apt-get install -f -y
rm wkhtmltox_0.12.6.1-2.jammy_amd64.deb

# Create odoo user
useradd -m -d /opt/odoo -U -r -s /bin/bash odoo

# Create directories
mkdir -p /opt/odoo/{odoo,custom-addons,logs,backups}
mkdir -p /var/log/odoo
mkdir -p /etc/odoo

# Mount additional EBS volume for data
mkfs.ext4 /dev/nvme1n1
echo '/dev/nvme1n1 /opt/odoo/data ext4 defaults 0 2' >> /etc/fstab
mkdir -p /opt/odoo/data
mount /opt/odoo/data
chown -R odoo:odoo /opt/odoo/data

# Clone Odoo from GitHub
cd /opt/odoo
git clone https://www.github.com/odoo/odoo --depth 1 --branch 16.0 odoo
chown -R odoo:odoo /opt/odoo

# Create Python virtual environment
sudo -u odoo python3 -m venv /opt/odoo/venv
sudo -u odoo /opt/odoo/venv/bin/pip install --upgrade pip

# Install Odoo dependencies
sudo -u odoo /opt/odoo/venv/bin/pip install -r /opt/odoo/odoo/requirements.txt
sudo -u odoo /opt/odoo/venv/bin/pip install psycopg2-binary boto3

# Create Odoo configuration file
cat > /etc/odoo/odoo.conf << EOF
[options]
; Database settings
db_host = $DB_ENDPOINT
db_port = 5432
db_user = $DB_USERNAME
db_password = $DB_PASSWORD
db_name = $DB_NAME

; Server settings
http_port = 8069
workers = 4
max_cron_threads = 2
limit_memory_hard = 2684354560
limit_memory_soft = 2147483648
limit_request = 8192
limit_time_cpu = 600
limit_time_real = 1200

; Logging
log_level = info
log_handler = :INFO
logfile = /var/log/odoo/odoo.log
log_db = False

; Security
admin_passwd = $(openssl rand -base64 32)
list_db = False
proxy_mode = True

; Paths
addons_path = /opt/odoo/odoo/addons,/opt/odoo/custom-addons
data_dir = /opt/odoo/data

; File upload
max_file_upload_size = 104857600

; Session
session_timeout = 3600
EOF

chown odoo:odoo /etc/odoo/odoo.conf
chmod 640 /etc/odoo/odoo.conf

# Create systemd service file
cat > /etc/systemd/system/odoo.service << EOF
[Unit]
Description=Odoo
Documentation=http://www.odoo.com
After=network.target postgresql.service

[Service]
Type=simple
SyslogIdentifier=odoo
PermissionsStartOnly=true
User=odoo
Group=odoo
ExecStart=/opt/odoo/venv/bin/python3 /opt/odoo/odoo/odoo-bin -c /etc/odoo/odoo.conf
StandardOutput=journal+console
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF

# Configure Nginx as reverse proxy
cat > /etc/nginx/sites-available/odoo << EOF
upstream odoo {
    server 127.0.0.1:8069;
}

upstream odoochat {
    server 127.0.0.1:8072;
}

map \$http_upgrade \$connection_upgrade {
    default upgrade;
    ''      close;
}

server {
    listen 80;
    server_name _;

    # Security headers
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header X-XSS-Protection "1; mode=block" always;
    add_header Referrer-Policy "no-referrer-when-downgrade" always;
    add_header Content-Security-Policy "default-src 'self' http: https: data: blob: 'unsafe-inline'" always;

    # Gzip compression
    gzip on;
    gzip_vary on;
    gzip_min_length 1024;
    gzip_proxied expired no-cache no-store private must-revalidate auth;
    gzip_types text/plain text/css text/xml text/javascript application/x-javascript application/xml+rss;

    # Proxy settings
    proxy_read_timeout 720s;
    proxy_connect_timeout 720s;
    proxy_send_timeout 720s;
    proxy_set_header X-Forwarded-Host \$host;
    proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
    proxy_set_header X-Forwarded-Proto \$scheme;
    proxy_set_header X-Real-IP \$remote_addr;

    # Health check endpoint
    location /web/health {
        access_log off;
        return 200 "healthy\n";
        add_header Content-Type text/plain;
    }

    # Handle longpoll requests
    location /longpolling {
        proxy_pass http://odoochat;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection \$connection_upgrade;
        proxy_set_header X-Forwarded-Host \$host;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_set_header X-Real-IP \$remote_addr;
    }

    # Handle all other requests
    location / {
        proxy_pass http://odoo;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection \$connection_upgrade;
        proxy_set_header X-Forwarded-Host \$host;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_set_header X-Real-IP \$remote_addr;
    }

    # Static files
    location ~* /web/static/ {
        proxy_cache_valid 200 90m;
        proxy_buffering on;
        expires 864000;
        proxy_pass http://odoo;
    }

    # File upload size
    client_max_body_size 100M;
}
EOF

# Enable Nginx site
ln -sf /etc/nginx/sites-available/odoo /etc/nginx/sites-enabled/
rm -f /etc/nginx/sites-enabled/default

# Configure CloudWatch agent
cat > /opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json << EOF
{
    "agent": {
        "metrics_collection_interval": 60,
        "run_as_user": "cwagent"
    },
    "logs": {
        "logs_collected": {
            "files": {
                "collect_list": [
                    {
                        "file_path": "/var/log/odoo/odoo.log",
                        "log_group_name": "/aws/ec2/$PROJECT_NAME-$ENVIRONMENT/odoo",
                        "log_stream_name": "{instance_id}/odoo.log"
                    },
                    {
                        "file_path": "/var/log/nginx/access.log",
                        "log_group_name": "/aws/ec2/$PROJECT_NAME-$ENVIRONMENT/nginx",
                        "log_stream_name": "{instance_id}/access.log"
                    },
                    {
                        "file_path": "/var/log/nginx/error.log",
                        "log_group_name": "/aws/ec2/$PROJECT_NAME-$ENVIRONMENT/nginx",
                        "log_stream_name": "{instance_id}/error.log"
                    }
                ]
            }
        }
    },
    "metrics": {
        "namespace": "CWAgent",
        "metrics_collected": {
            "cpu": {
                "measurement": [
                    "cpu_usage_idle",
                    "cpu_usage_iowait",
                    "cpu_usage_user",
                    "cpu_usage_system"
                ],
                "metrics_collection_interval": 60
            },
            "disk": {
                "measurement": [
                    "used_percent"
                ],
                "metrics_collection_interval": 60,
                "resources": [
                    "*"
                ]
            },
            "diskio": {
                "measurement": [
                    "io_time"
                ],
                "metrics_collection_interval": 60,
                "resources": [
                    "*"
                ]
            },
            "mem": {
                "measurement": [
                    "mem_used_percent"
                ],
                "metrics_collection_interval": 60
            },
            "netstat": {
                "measurement": [
                    "tcp_established",
                    "tcp_time_wait"
                ],
                "metrics_collection_interval": 60
            },
            "swap": {
                "measurement": [
                    "swap_used_percent"
                ],
                "metrics_collection_interval": 60
            }
        }
    }
}
EOF

# Configure log rotation
cat > /etc/logrotate.d/odoo << EOF
/var/log/odoo/*.log {
    daily
    missingok
    rotate 30
    compress
    delaycompress
    notifempty
    create 644 odoo odoo
    postrotate
        systemctl reload odoo
    endscript
}
EOF

# Configure firewall
ufw --force enable
ufw default deny incoming
ufw default allow outgoing
ufw allow ssh
ufw allow 80
ufw allow 443
ufw allow from 10.0.0.0/16 to any port 8069

# Configure fail2ban
cat > /etc/fail2ban/jail.local << EOF
[DEFAULT]
bantime = 3600
findtime = 600
maxretry = 5

[sshd]
enabled = true
port = ssh
logpath = /var/log/auth.log
maxretry = 3

[nginx-http-auth]
enabled = true
port = http,https
logpath = /var/log/nginx/error.log

[nginx-limit-req]
enabled = true
port = http,https
logpath = /var/log/nginx/error.log
maxretry = 10
EOF

# Set proper permissions
chown -R odoo:odoo /opt/odoo
chown -R odoo:odoo /var/log/odoo
chmod -R 755 /opt/odoo
chmod 640 /etc/odoo/odoo.conf

# Create backup script
cat > /opt/odoo/backup.sh << 'EOF'
#!/bin/bash
# Odoo backup script

BACKUP_DIR="/opt/odoo/backups"
DATE=$(date +%Y%m%d_%H%M%S)
DB_NAME="${db_name}"
BACKUP_BUCKET="${backup_bucket}"

# Create database backup
pg_dump -h $DB_ENDPOINT -U $DB_USERNAME -d $DB_NAME > $BACKUP_DIR/odoo_db_$DATE.sql

# Create filestore backup
tar -czf $BACKUP_DIR/odoo_filestore_$DATE.tar.gz /opt/odoo/data/filestore

# Upload to S3
aws s3 cp $BACKUP_DIR/odoo_db_$DATE.sql s3://$BACKUP_BUCKET/database/
aws s3 cp $BACKUP_DIR/odoo_filestore_$DATE.tar.gz s3://$BACKUP_BUCKET/filestore/

# Clean up local backups older than 7 days
find $BACKUP_DIR -name "*.sql" -mtime +7 -delete
find $BACKUP_DIR -name "*.tar.gz" -mtime +7 -delete

echo "Backup completed: $DATE"
EOF

chmod +x /opt/odoo/backup.sh
chown odoo:odoo /opt/odoo/backup.sh

# Add backup cron job
echo "0 2 * * * odoo /opt/odoo/backup.sh >> /var/log/odoo/backup.log 2>&1" >> /etc/crontab

# Start and enable services
systemctl daemon-reload
systemctl enable odoo
systemctl enable nginx
systemctl enable amazon-cloudwatch-agent
systemctl enable fail2ban

# Start CloudWatch agent
/opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl \
    -a fetch-config \
    -m ec2 \
    -c file:/opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json \
    -s

# Test Nginx configuration
nginx -t

# Start services
systemctl start fail2ban
systemctl start nginx
systemctl start odoo

# Wait for Odoo to start
sleep 30

# Initialize database if it doesn't exist
if ! PGPASSWORD=$DB_PASSWORD psql -h $DB_ENDPOINT -U $DB_USERNAME -d $DB_NAME -c '\q' 2>/dev/null; then
    echo "Initializing Odoo database..."
    sudo -u odoo /opt/odoo/venv/bin/python3 /opt/odoo/odoo/odoo-bin \
        -c /etc/odoo/odoo.conf \
        -d $DB_NAME \
        --init=base \
        --stop-after-init
fi

echo "Odoo installation completed at $(date)"
echo "Odoo should be accessible on port 8069"