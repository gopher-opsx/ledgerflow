FROM maven:3.9-eclipse-temurin-21 AS build
WORKDIR /src
COPY streams/pom.xml ./pom.xml
RUN mvn -q -DskipTests dependency:go-offline
COPY streams/src ./src
RUN mvn -q -DskipTests package

FROM eclipse-temurin:21-jre
WORKDIR /app
COPY --from=build /src/target/ledgerflow-streams-1.0.0.jar /app/ledgerflow-streams.jar
ENTRYPOINT ["java", "-jar", "/app/ledgerflow-streams.jar"]
