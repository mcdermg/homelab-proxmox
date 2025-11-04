#!/bin/bash
# Create Gitea database and user
su - postgres -c "psql -c \"CREATE DATABASE gitea;\""
su - postgres -c "psql -c \"CREATE USER gitea WITH PASSWORD 'GiteaDB123';\""
su - postgres -c "psql -c \"GRANT ALL PRIVILEGES ON DATABASE gitea TO gitea;\""
# Configure remote access (REQUIRED for Gitea to connect)
echo "host    gitea    gitea    192.168.1.117/32    scram-sha-256" >> /etc/postgresql/*/main/pg_hba.conf
sed -i "s/#listen_addresses = 'localhost'/listen_addresses = '192.168.1.116'/" /etc/postgresql/*/main/postgresql.conf
systemctl restart postgresql
