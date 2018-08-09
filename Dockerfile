FROM openjdk:8
VOLUME /tmp
ADD spring-petclinic-2.0.0.BUILD-SNAPSHOT.jar /app.jar
ENV SPRING_PROFILES_ACTIVE docker
RUN bash -c 'touch /app.jar'
#EXPOSE 8080
ENTRYPOINT ["java", "-XX:+UnlockExperimentalVMOptions", "-XX:+UseCGroupMemoryLimitForHeap", "-Djava.security.egd=file:/dev/./urandom","-jar","/app.jar"]
