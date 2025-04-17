#!/bin/bash

# Set environment variable to prevent interactive prompts
export DEBIAN_FRONTEND=noninteractive

# Directory configurations
SETUP_DIR="/root/webapp-setup"
APP_DIR="/opt/csye6225"
APP_GROUP="webapp_group"
APP_USER="webapp_user"

echo "Starting application setup..."

# First, check if we are root
if [ "$EUID" -ne 0 ]; then 
    echo "Please run as root"
    exit 1
fi

# Check if required files exist
if [ ! -f "$SETUP_DIR/webapp.zip" ]; then
    echo "Error: webapp.zip not found in $SETUP_DIR"
    exit 1
fi

# Update and upgrade packages
echo "Updating system packages..."
apt-get update -y
apt-get upgrade -y

# Install necessary tools including unzip
echo "Installing necessary tools..."
apt-get install -y unzip

# Install PostgreSQL
echo "Installing PostgreSQL..."
apt-get install -y postgresql postgresql-contrib

# Start PostgreSQL service
systemctl start postgresql
systemctl enable postgresql

# Extract database details from DATABASE_URL
DB_URL=$(grep DATABASE_URL "$SETUP_DIR/.env" | cut -d '=' -f2- | tr -d '\r')
DB_NAME=$(echo "$DB_URL" | awk -F'/' '{print $NF}' | tr -d '\r')
DB_USER=$(echo "$DB_URL" | grep -oP 'postgres://\K[^:]+')
DB_PASS=$(echo "$DB_URL" | grep -oP '://[^:]+:\K[^@]+')

# Debug output
echo "Database configuration:"
echo "Database: $DB_NAME"
echo "User: $DB_USER"

# Modify pg_hba.conf to use md5 authentication
echo "Configuring PostgreSQL authentication..."
sed -i 's/local   all             all                                     peer/local   all             all                                     md5/' /etc/postgresql/*/main/pg_hba.conf
sed -i 's/host    all             all             127.0.0.1\/32            scram-sha-256/host    all             all             127.0.0.1\/32            md5/' /etc/postgresql/*/main/pg_hba.conf

# Restart PostgreSQL to apply changes
systemctl restart postgresql

# Check if database exists
DB_EXISTS=$(sudo -u postgres psql -tAc "SELECT 1 FROM pg_database WHERE datname='$DB_NAME'" | grep -q 1; echo $?)

if [ "$DB_EXISTS" -ne 0 ]; then
    echo "Database does not exist. Creating database..."
    # Create database
    sudo -u postgres psql -c "CREATE DATABASE \"$DB_NAME\";"
    # Create user if not exists
    sudo -u postgres psql -c "DO \$\$
    BEGIN
        IF NOT EXISTS (SELECT FROM pg_user WHERE usename = '$DB_USER') THEN
            CREATE USER \"$DB_USER\" WITH PASSWORD '$DB_PASS';
        END IF;
    END
    \$\$;"
    # Grant privileges
    sudo -u postgres psql -c "GRANT ALL PRIVILEGES ON DATABASE \"$DB_NAME\" TO \"$DB_USER\";"
    # Grant schema privileges
    sudo -u postgres psql -d $DB_NAME -c "GRANT ALL ON SCHEMA public TO \"$DB_USER\";"
else
    echo "Database already exists. Updating permissions..."
    # Ensure user has correct permissions even if DB exists
    sudo -u postgres psql -c "DO \$\$
    BEGIN
        IF NOT EXISTS (SELECT FROM pg_user WHERE usename = '$DB_USER') THEN
            CREATE USER \"$DB_USER\" WITH PASSWORD '$DB_PASS';
        ELSE
            ALTER USER \"$DB_USER\" WITH PASSWORD '$DB_PASS';
        END IF;
    END
    \$\$;"
    sudo -u postgres psql -c "GRANT ALL PRIVILEGES ON DATABASE \"$DB_NAME\" TO \"$DB_USER\";"
    sudo -u postgres psql -d $DB_NAME -c "GRANT ALL ON SCHEMA public TO \"$DB_USER\";"
fi

# Install Node.js and npm properly
echo "Installing Node.js and npm..."
# Remove any existing installations
apt-get remove -y nodejs npm
apt-get autoremove -y
apt-get clean

# Add NodeSource repository properly
curl -fsSL https://deb.nodesource.com/setup_20.x | bash -
# Fix any broken packages
apt-get install -f
# Install nodejs
apt-get install -y nodejs

# Verify Node.js and npm installation
echo "Verifying Node.js and npm installation..."
node --version
npm --version

# Create and setup application directory properly
echo "Setting up application directory..."
mkdir -p $APP_DIR
cd $SETUP_DIR

echo "Unzipping application..."
# Clear the destination directory first
rm -rf $APP_DIR/webapp
unzip -o webapp.zip -d $APP_DIR

# Verify the webapp directory exists
if [ ! -d "$APP_DIR/webapp" ]; then
    echo "Error: Webapp directory not created correctly"
    echo "Contents of $APP_DIR:"
    ls -la $APP_DIR
    exit 1
fi

# Update permissions
echo "Setting permissions..."
chown -R $APP_USER:$APP_GROUP $APP_DIR
chmod -R 750 $APP_DIR

# Install PM2 globally
echo "Installing PM2..."
npm install -g pm2
# Verify PM2 installation
pm2 --version

# Install application dependencies
echo "Installing application dependencies..."
cd $APP_DIR/webapp
if [ ! -f "package.json" ]; then
    echo "Error: package.json not found in $APP_DIR/webapp"
    exit 1
fi

su - $APP_USER -c "cd $APP_DIR/webapp && npm install"

# Setup PM2 with systemd
echo "Setting up PM2 with systemd..."
pm2 startup systemd -u $APP_USER --hp /home/$APP_USER

echo "Starting application..."
su - $APP_USER -c "cd $APP_DIR/webapp && pm2 start app.js --name webapp"
su - $APP_USER -c "pm2 save"

echo "Setup complete!"
echo "Checking application status..."
su - $APP_USER -c "pm2 status"

# Print verification steps
echo ""
echo "To verify the setup:"
echo "1. Check database: sudo -u postgres psql -l"
echo "2. Check permissions: ls -ls /opt"
echo "3. Test database connection: psql -h localhost -U $DB_USER -d $DB_NAME"