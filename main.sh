#!/bin/sh/

export USERNAME=pi

# Set up

echo "Configuring environment and installing dependencies..."

sudo apt-get update
sudo mkdir /data
sudo chown $USERNAME /data

sudo apt install git -y

git clone https://github.com/pyenv/pyenv.git /data/pyenv
cd /data/pyenv && src/configure && make -C src
echo 'export PYENV_ROOT="/data/pyenv"' >> ~/.bash_profile
echo 'export PATH="$PYENV_ROOT/bin:$PATH"' >> ~/.bash_profile
echo -e 'if command -v pyenv 1>/dev/null 2>&1; then\n  eval "$(pyenv init -)"\nfi' >> ~/.bash_profile

source ~/.bash_profile
# dependencies for pyenv
sudo apt-get install --no-install-recommends make build-essential libssl-dev zlib1g-dev \
    libbz2-dev libreadline-dev libsqlite3-dev wget curl llvm libncurses5-dev xz-utils \
    tk-dev libxml2-dev libxmlsec1-dev libffi-dev liblzma-dev -y

# dependencies for pillow
sudo apt install libjpeg8-dev libopenjp2-7-dev zlib1g-dev \
    libfreetype6-dev liblcms2-dev libwebp-dev tcl8.6-dev tk8.6-dev python3-tk \
    libharfbuzz-dev libfribidi-dev libxcb1-dev -y

# for some reason this fails if you install it with the earlier block ¯\_(ツ)_/¯
sudo apt install libtiff5-dev -y

sudo apt install nginx -y

pyenv install 3.9.2
pyenv global 3.9.2
pip install --upgrade pip
pip install wheel

# necessary so we don't trip over the ridiculous rust change in cryptography
# https://github.com/pyca/cryptography/issues/5771
# https://github.com/pyca/cryptography/issues/5861
pip install cryptography==3.3.2 --no-cache-dir

pip install poetry
poetry config virtualenvs.in-project true

cd /data
git clone https://github.com/AlexandriaILS/Alexandria alexandria
git clone https://github.com/AlexandriaILS/Zenodotus zenodotus

# install and configure AlexandriaILS

echo "Installing AlexandriaILS..."

cd /data/alexandria
poetry install

export PYTHON=.venv/bin/python

$PYTHON manage.py migrate
echo "from django.contrib.auth import get_user_model; User = get_user_model(); User.objects.create_superuser('1234', 'admin@myproject.com', 'asdf')" | $PYTHON manage.py shell
$PYTHON manage.py collectstatic --noinput
$PYTHON manage.py bootstrap_types

# This should go into a loop but for some reason the files don't want to write. Something to look at later on.
sudo bash -c '
cat > /etc/systemd/system/alexandria.service << EOF
[Unit]
Description=alexandria gunicorn daemon
After=network.target

[Service]
User=root
Group=www-data
WorkingDirectory=/data/alexandria
ExecStart=/data/alexandria/.venv/bin/gunicorn \
    --access-logfile - \
    --workers=4 \
    -b unix:/run/alexandria.sock \
    alexandria.wsgi:application

[Install]
WantedBy=multi-user.target
EOF
'

sudo bash -c '
cat > /etc/systemd/system/alexandria.socket << EOF
[Unit]
Description=alexandria socket

[Socket]
ListenStream=/run/alexandria.sock

[Install]
WantedBy=sockets.target
EOF
'

echo "Installing Zenodotus..."

cd /data/zenodotus
poetry install

$PYTHON manage.py migrate
echo "from django.contrib.auth import get_user_model; User = get_user_model(); User.objects.create_superuser('1234', 'admin@myproject.com', 'asdf')" | $PYTHON manage.py shell
$PYTHON manage.py collectstatic --noinput
$PYTHON manage.py bootstrap_data


sudo bash -c '
cat > /etc/systemd/system/zenodotus.service << EOF
[Unit]
Description=zenodotus gunicorn daemon
After=network.target

[Service]
User=root
Group=www-data
WorkingDirectory=/data/zenodotus
ExecStart=/data/zenodotus/.venv/bin/gunicorn \
    --access-logfile - \
    --workers=4 \
    -b unix:/run/zenodotus.sock \
    zenodotus.wsgi:application

[Install]
WantedBy=multi-user.target
EOF
'

sudo bash -c '
cat > /etc/systemd/system/zenodotus.socket << EOF
[Unit]
Description=zenodotus socket

[Socket]
ListenStream=/run/zenodotus.sock

[Install]
WantedBy=sockets.target
EOF
'

sudo systemctl enable alexandria.service
sudo systemctl enable zenodotus.service

sudo systemctl start alexandria.service
sudo systemctl start zenodotus.service

echo "Installing Bubbles..."

cd /data

git clone https://github.com/AlexandriaILS/Bubbles-V2 bubbles
cd /data/bubbles
poetry install

sudo useradd -m bubbles

sudo bash -c '
cat > /etc/sudoers.d/bubbles << EOF
bubbles ALL= NOPASSWD: /bin/systemctl restart bubbles
bubbles ALL= NOPASSWD: /bin/systemctl stop bubbles
bubbles ALL= NOPASSWD: /bin/systemctl start bubbles
bubbles ALL= NOPASSWD: /bin/systemctl restart alexandria
bubbles ALL= NOPASSWD: /bin/systemctl stop alexandria
bubbles ALL= NOPASSWD: /bin/systemctl start alexandria
bubbles ALL= NOPASSWD: /bin/systemctl restart zenodotus
bubbles ALL= NOPASSWD: /bin/systemctl stop zenodotus
bubbles ALL= NOPASSWD: /bin/systemctl start zenodotus
EOF
'

sudo bash -c '
cat > /etc/systemd/system/bubbles.service << EOF
[Unit]
Description=Start Bubbles
After=network.service

[Service]
Environment="LC_ALL=en_US.UTF-8"
ExecStart=/data/bubbles/.venv/bin/python /data/bubbles/bubbles.py
WorkingDirectory=/data/bubbles
User=bubbles
Restart=always
KillSignal=SIGINT

[Install]
WantedBy=multi-user.target
EOF
'

# bubbles user has to own all the files or the update process won't work
sudo chown bubbles /data/bubbles/ -R
sudo chown bubbles /data/alexandria/ -R
sudo chown bubbles /data/zenodotus/ -R

sudo systemctl enable bubbles.service
sudo systemctl start bubbles.service