FROM public.ecr.aws/lambda/nodejs:18

# Install dependencies
COPY build/package.json build/package-lock.json ./
RUN npm install

# Install Chromium dependencies
RUN yum install -y \
    atk \
    cups-libs \
    gtk3 \
    libXcomposite \
    libXcursor \
    libXdamage \
    libXext \
    libXi \
    libXrandr \
    libXScrnSaver \
    libXtst \
    pango \
    alsa-lib \
    ipa-gothic-fonts \
    xorg-x11-fonts-100dpi \
    xorg-x11-fonts-75dpi \
    xorg-x11-fonts-cyrillic \
    xorg-x11-fonts-misc \
    xorg-x11-fonts-Type1 \
    xorg-x11-utils \
    && yum clean all

# Copy function code
COPY build/index.js .

# Set the CMD to your handler
CMD ["index.handler"] 