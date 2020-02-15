FROM registry.redhat.io/ubi8/ubi
RUN yum install -y ruby && \
    gem install redis
COPY main.rb .
CMD ["ruby", "main.rb"]
