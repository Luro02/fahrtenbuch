FROM nginx:stable

WORKDIR /app

RUN apt-get update
RUN apt-get install -y curl git unzip

# define variables
ARG FLUTTER_SDK=/usr/local/flutter
ARG FLUTTER_VERSION=3.19.2
ARG APP=/app/

# setup flutter:
RUN git clone https://github.com/flutter/flutter.git $FLUTTER_SDK
RUN cd $FLUTTER_SDK && git fetch && git checkout $FLUTTER_VERSION

ENV PATH="$FLUTTER_SDK/bin:$FLUTTER_SDK/bin/cache/dart-sdk/bin:${PATH}"

RUN flutter doctor -v

# copy flutter app to container:
COPY . .

# load dependencies
RUN flutter clean
RUN flutter pub get
# run the build for the container, so the web sdk is downloaded
RUN flutter build web --release
# real build is done in the run.sh file

ENV API_URL=http://127.0.0.1:3000

RUN chmod +x /app/run.sh

EXPOSE 80
ENTRYPOINT [ "/app/run.sh" ]
