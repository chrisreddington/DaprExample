########################################
#
# Stage 1: Build
#
# Use the larger dev image for the build
#
########################################

# Set the base image as the latest minor version.
# This will be used for the build. This will require
# manual intervention to update the image if a new version
# of the image is released.
FROM golang:1.18-alpine AS build

# Set the working directory to the /src directory. All relative
# paths will be resolved from here.
WORKDIR /src

# Copy the go.mod and go.sum files to the /src directory, so 
# that they can be used by the build to download the latest
# dependencies.
COPY go.mod .
COPY go.sum .
RUN go mod download

# Copy the remaining source files to the /src directory.
COPY . .

# Build the image.
RUN go build -o /app cmd/httpserver/main.go

########################################
#
# Stage 2: Production
#
# Use a smaller alpine base image for the
# production image. This means that the 
# image will be smaller and faster to build.
# It also means that the image will have a
# smaller attack surface.
#
########################################

# Set the base image as the latest minor version.
# This will be used for the production image. This will require
# manual intervention to update the image if a new version
# of the image is released.
FROM alpine:3.15

# Use the alpine package manager. --update will ensure that
# the cache is up to date. Then, make sure the CA certificates
# are installed.
RUN apk --update add ca-certificates

# Add a user and group. Creating this user means we can
# later switch to a non-root user to execute the app.
RUN adduser -D -g 'app' app

# Copy the output of the build to the /app directory in the
# production image. This will be the binary that is run.
# That binary will need to have it's permissions set to
# executable.
COPY --from=build --chown=app:app /app /app
RUN chmod +x /app

# Expose the port to the host. Update this if the underlying
# app uses a different port.
EXPOSE 6002

# Switch the user to the app user. This will allow the app
# to run as the user and group instead of root.
USER app

# Finally, run the go executable on container startup.
ENTRYPOINT ["/app"]