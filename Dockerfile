FROM perl:5.28.1

ENV LANG C.UTF-8

RUN cpanm Carton

WORKDIR /app