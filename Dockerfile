FROM php:8.1-apache

# 1. Use the "Pickle" installer (The fast way)
# This downloads pre-compiled extensions instead of building them
COPY --from=mlocati/php-extension-installer /usr/bin/install-php-extensions /usr/local/bin/

# 2. Install gRPC and Protobuf instantly
RUN install-php-extensions grpc protobuf

# 3. Install Composer
COPY --from=composer:latest /usr/bin/composer /usr/bin/composer

# 4. Copy your project files
COPY . /var/www/html
WORKDIR /var/www/html

# 5. Install PHP libraries
# We use --ignore-platform-reqs to avoid errors during the build
RUN composer install --no-dev --optimize-autoloader --ignore-platform-reqs

# 6. Configure Apache to listen on Render's Port
RUN sed -i 's/80/${PORT}/g' /etc/apache2/sites-available/000-default.conf /etc/apache2/ports.conf

# 7. Start the server
CMD ["apache2-foreground"]
