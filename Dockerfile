# 使用多阶段构建来减少最终镜像的大小
# 第一阶段：构建 Go 程序
FROM --platform=$BUILDPLATFORM golang:alpine AS builder

# 设置工作目录
WORKDIR /app

# 将 Go 代码复制到容器中
COPY main.go .

# 禁用 Go Modules
ENV GO111MODULE=off

# 打印调试信息
ARG TARGETARCH
RUN echo "Building for architecture: $TARGETARCH"

# 编译 Go 程序，并静态链接以减小二进制文件大小
RUN CGO_ENABLED=0 GOOS=linux GOARCH=$TARGETARCH go build -o hello .

# 第二阶段：从 scratch 开始构建最小化镜像
FROM scratch

# 将编译好的二进制文件从 builder 阶段复制到当前阶段
COPY --from=builder /app/hello /hello

# 设置容器启动时执行的命令
CMD ["/hello"]