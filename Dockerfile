FROM php:8.1-apache

# Install dependencies for Firebase (gRPC and Protobuf)
# Note: This takes a few minutes to build
RUN apt-get update && apt-get install -y \
    zlib1g-dev \
    libgrpc-dev \
    && pecl install grpc protobuf \
    && docker-php-ext-enable grpc protobuf

# Install Composer
COPY --from=composer:latest /usr/bin/composer /usr/bin/composer

# Copy files
COPY . /var/www/html
WORKDIR /var/www/html

# Install PHP libraries
RUN composer install --no-dev --optimize-autoloader

# Allow Apache to use the PORT environment variable from Render
RUN sed -i 's/80/${PORT}/g' /etc/apache2/sites-available/000-default.conf /etc/apache2/ports.conf

# Start Apache
CMD ["apache2-foreground"]
