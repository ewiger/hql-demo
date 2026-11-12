# Apache Spark with Delta Lake and the S3 connector: an open-source
# lakehouse SQL endpoint. The jars are fetched once, when the image is
# built, so starting a container needs no network.
FROM apache/spark:3.5.6

ARG MAVEN=https://repo1.maven.org/maven2
ARG DELTA=3.3.2
ARG HADOOP_AWS=3.3.4
ARG AWS_SDK=1.12.262

USER root
ADD --chmod=644 ${MAVEN}/io/delta/delta-spark_2.12/${DELTA}/delta-spark_2.12-${DELTA}.jar /opt/spark/jars/
ADD --chmod=644 ${MAVEN}/io/delta/delta-storage/${DELTA}/delta-storage-${DELTA}.jar /opt/spark/jars/
ADD --chmod=644 ${MAVEN}/org/apache/hadoop/hadoop-aws/${HADOOP_AWS}/hadoop-aws-${HADOOP_AWS}.jar /opt/spark/jars/
ADD --chmod=644 ${MAVEN}/com/amazonaws/aws-java-sdk-bundle/${AWS_SDK}/aws-java-sdk-bundle-${AWS_SDK}.jar /opt/spark/jars/
COPY spark-defaults.conf /opt/spark/conf/spark-defaults.conf
USER spark

# The Thrift Server, in the foreground, answering HiveServer2's protocol
# over HTTP on port 10001 at /cliservice, as a Databricks SQL warehouse
# does at its HTTP path.
CMD ["/opt/spark/bin/spark-submit", \
     "--class", "org.apache.spark.sql.hive.thriftserver.HiveThriftServer2", \
     "--name", "hql-demo lakehouse", \
     "--master", "local[2]", \
     "--hiveconf", "hive.server2.transport.mode=http", \
     "--hiveconf", "hive.server2.thrift.http.port=10001", \
     "--hiveconf", "hive.server2.thrift.http.path=cliservice", \
     "spark-internal"]
