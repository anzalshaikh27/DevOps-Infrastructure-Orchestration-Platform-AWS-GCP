#!/bin/bash
 
# Update package list
sudo apt update -y
sudo apt-get upgrade -y
 
# Install required dependencies
sudo apt install -y unzip
 
# Install Node.js
curl -fsSL https://deb.nodesource.com/setup_20.x | sudo -E bash -
sudo apt-get update  # Update again after adding Node.js repo
sudo apt-get install -y nodejs

# Verify Node.js installation
node --version
npm --version

# Install PostgreSQL
sudo apt install -y postgresql postgresql-contrib

# Start PostgreSQL service
sudo systemctl enable postgresql
sudo systemctl start postgresql
sleep 5  # Give PostgreSQL time to start
 
# Create a non-login user for running the app
sudo adduser --system --group --no-create-home csye6225
 
# Create application directory
sudo mkdir -p /opt/app/webapp
sleep 5

# Extract application files
sudo unzip -o /tmp/webapp.zip -d /opt/app/webapp
sudo rm /tmp/webapp.zip

# Change permissions
echo 'Changing permission for user and group'
sudo chown -R csye6225:csye6225 /opt/app/webapp
sudo chmod -R 755 /opt/app/webapp
sleep 5 
 
# Move to application directory
cd /opt/app/webapp
 
# Install Node.js dependencies
sudo npm install --no-progress
 
# Copy systemd service file
sudo cp /tmp/systemd.service /etc/systemd/system/csye6225.service
sudo rm /tmp/systemd.service
 
# Reload systemd and enable service
sudo systemctl daemon-reload
sudo systemctl enable csye6225.service

#GCP changes

# Verify they are enabled
sudo systemctl is-enabled postgresql
sudo systemctl is-enabled csye6225.service

# Create startup verification script
sudo tee /opt/app/webapp/startup-check.sh << 'EOL'
#!/bin/bash
# Wait for PostgreSQL to be ready
timeout 60 bash -c 'until pg_isready; do sleep 1; done'
# Start our service
sudo systemctl start csye6225.service
EOL

sudo chmod +x /opt/app/webapp/startup-check.sh

# Add to startup
sudo tee /etc/systemd/system/startup-check.service << 'EOL'
[Unit]
Description=Startup Check Service
After=postgresql.service
Wants=postgresql.service

[Service]
Type=oneshot
ExecStart=/opt/app/webapp/startup-check.sh
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
EOL

sudo systemctl enable startup-check.service

#GCP verification
sudo systemctl status csye6225.service
 
# Create log directory
sudo mkdir -p /var/log/webapp
sudo chown -R csye6225:csye6225 /var/log/webapp
 
echo "Setup complete! PostgreSQL and web application are configured."