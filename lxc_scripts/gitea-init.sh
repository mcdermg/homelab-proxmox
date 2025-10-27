#!/bin/bash
# Wait for PostgreSQL
until timeout 1 bash -c "</dev/tcp/192.168.1.116/5432" 2>/dev/null; do
  echo "Waiting for PostgreSQL..."
  sleep 2
done
# Only modify app.ini if still using MySQL
if grep -q "DB_TYPE.*=.*mysql" /home/git/custom/conf/app.ini; then
  systemctl stop gitea
  cp /home/git/custom/conf/app.ini /home/git/custom/conf/app.ini.bak
  sed -i '/^\[database\]/,/^\[/ s/^DB_TYPE.*/DB_TYPE = postgres/' /home/git/custom/conf/app.ini
  sed -i '/^\[database\]/,/^\[/ s/^HOST.*/HOST = 192.168.1.116:5432/' /home/git/custom/conf/app.ini
  sed -i '/^\[database\]/,/^\[/ s/^NAME.*/NAME = gitea/' /home/git/custom/conf/app.ini
  sed -i '/^\[database\]/,/^\[/ s/^USER.*/USER = gitea/' /home/git/custom/conf/app.ini
  sed -i '/^\[database\]/,/^\[/ s/^PASSWD.*/PASSWD = GiteaDB123/' /home/git/custom/conf/app.ini
  systemctl start gitea
  sleep 5
fi
# Only create user if doesn't exist
if ! su - git -c "cd /home/git && ./gitea admin user list 2>/dev/null" | grep -qw "gitea"; then
  su - git -c "cd /home/git && ./gitea admin user create \
    --username gitea \
    --password GiteaAdmin123 \
    --email gary@homelab.local \
    --admin"
fi
