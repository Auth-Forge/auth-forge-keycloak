# Declare the ARGs before any FROM directives
ARG KC_VERSION=22.0.3

FROM maven:3.8.6-openjdk-11-slim AS spi-builder

ARG GITHUB_USERNAME

# Create the .m2 directory
RUN mkdir -p /root/.m2

# Create a settings.xml file with GitHub credentials using heredoc
RUN --mount=type=secret,id=github_token \
    TOKEN=$(cat /run/secrets/github_token) && \
    echo "\
<settings xmlns=\"http://maven.apache.org/SETTINGS/1.0.0\" xmlns:xsi=\"http://www.w3.org/2001/XMLSchema-instance\" xsi:schemaLocation=\"http://maven.apache.org/SETTINGS/1.0.0 http://maven.apache.org/xsd/settings-1.0.0.xsd\">\n\
  <activeProfiles>\n\
    <activeProfile>github</activeProfile>\n\
  </activeProfiles>\n\
  <profiles>\n\
    <profile>\n\
      <id>github</id>\n\
      <repositories>\n\
        <repository>\n\
          <id>central</id>\n\
          <url>https://repo1.maven.org/maven2</url>\n\
        </repository>\n\
        <repository>\n\
          <id>github</id>\n\
          <url>https://maven.pkg.github.com/Auth-Forge/auth-forge-spi</url>\n\
          <snapshots>\n\
            <enabled>true</enabled>\n\
          </snapshots>\n\
        </repository>\n\
      </repositories>\n\
    </profile>\n\
  </profiles>\n\
  <servers>\n\
    <server>\n\
      <id>github</id>\n\
      <username>${GITHUB_USERNAME}</username>\n\
      <password>${TOKEN}</password>\n\
    </server>\n\
  </servers>\n\
</settings>" > /root/.m2/settings.xml

# Download the package using Maven
RUN mvn dependency:get \
    -DrepoUrl=https://maven.pkg.github.com/Auth-Forge/auth-forge-spi \
    -Dartifact=io.authforge:auth-forge-spi:0.0.1-SNAPSHOT


# Second stage: Build Keycloak image
FROM quay.io/keycloak/keycloak:${KC_VERSION}

# Copy the downloaded package from the previous stage
COPY --from=spi-builder /root/.m2/repository/io/authforge/auth-forge-spi/0.0.1-SNAPSHOT/auth-forge-spi-0.0.1-SNAPSHOT.jar /opt/keycloak/providers/

# Copy your Keycloak realm export and custom themes
COPY ./keycloak/realm-export-bank.json /opt/keycloak/data/import/realm-export-bank.json
COPY ./keycloak/themes /opt/keycloak/themes

CMD ["start-dev", "--import-realm"]




