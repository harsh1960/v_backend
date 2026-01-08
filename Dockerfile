FROM php:8.1-apache

# 1. Install the Extension Installer Script
# This tool downloads pre-compiled binaries so you don't have to compile from source
ADD https://github.com/mlocati/docker-php-extension-installer/releases/latest/download/install-php-extensions /usr/local/bin/

# 2. Install gRPC and Protobuf (Fast method)
RUN chmod +x /usr/local/bin/install-php-extensions && \
    install-php-extensions grpc protobuf

# 3. Install Composer
COPY --from=composer:latest /usr/bin/composer /usr/bin/composer

# 4. Copy files
COPY . /var/www/html
WORKDIR /var/www/html

# 5. Install PHP libraries
# We use --ignore-platform-reqs to prevent Composer from complaining about missing extensions during the build
RUN composer install --no-dev --optimize-autoloader --ignore-platform-reqs

# 6. Configure Apache Port
RUN sed -i 's/80/${PORT}/g' /etc/apache2/sites-available/000-default.conf /etc/apache2/ports.conf

# 7. Start Apache
CMD ["apache2-foreground"]
