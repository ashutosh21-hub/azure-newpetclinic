# Multi-stage Docker build for Spring PetClinic (Java 21)

# Stage 1: Build
FROM maven:3.9.6-eclipse-temurin-21 AS builder

WORKDIR /build

# Copy pom.xml and source code
COPY pom.xml .
RUN mvn dependency:go-offline -B

COPY src ./src

# Build application
RUN mvn clean package -DskipTests -Dorg.slf4j.simpleLogger.defaultLogLevel=warn

# Stage 2: Runtime
FROM eclipse-temurin:21-jre-alpine

LABEL maintainer="DevOps Team"
LABEL description="Spring PetClinic Application"
LABEL version="1.0"

# Create non-root user and group
RUN addgroup -S appgroup && adduser -S appuser -G appgroup

# Install curl for health checks (Alpine version)
RUN apk add --no-cache curl

# Set working directory
WORKDIR /app

# Copy JAR from builder stage
COPY --from=builder /build/target/*.jar ./app.jar

# Change ownership
RUN chown -R appuser:appgroup /app

# Switch to non-root user
USER appuser

# Expose port
EXPOSE 8080

# Health check (matches Spring Boot Actuator endpoint)
HEALTHCHECK --interval=30s --timeout=3s --start-period=40s --retries=3 \
    CMD curl -f http://localhost:8080/actuator/health/liveness || exit 1

# JVM options
ENV JAVA_OPTS="-XX:+UseG1GC -XX:MaxGCPauseMillis=200 -XX:+ParallelRefProcEnabled -Xms256m -Xmx512m"

# Run application
ENTRYPOINT exec java $JAVA_OPTS -jar app.jar
