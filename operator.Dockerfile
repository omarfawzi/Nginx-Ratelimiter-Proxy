FROM golang:1.24 as builder
WORKDIR /workspace
COPY operator/go.mod operator/go.sum ./operator/
WORKDIR /workspace/operator
RUN go mod download
COPY operator/ .
RUN CGO_ENABLED=0 go build -o manager cmd/main.go

FROM gcr.io/distroless/static
WORKDIR /
COPY --from=builder /workspace/operator/manager ./
ENTRYPOINT ["/manager"]
