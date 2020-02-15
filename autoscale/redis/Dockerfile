FROM registry.redhat.io/ubi8/ubi
RUN yum install -y wget make gcc && \
    wget http://download.redis.io/releases/redis-5.0.7.tar.gz && \
    tar xzf redis-5.0.7.tar.gz && \
    cd redis-5.0.7 && \
    make MALLOC=libc

ENV PATH=/redis-5.0.7/src

EXPOSE 6379
CMD ["redis-server", "--protected-mode", "no"]

