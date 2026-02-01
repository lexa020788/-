FROM //mcr.microsoft.com AS build-env
WORKDIR /app

COPY . .
RUN dotnet publish -c Release -o output

FROM debian:12
WORKDIR /app

RUN apt-get update && apt-get install -y libicu72 libssl3 && rm -rf /var/lib/apt/lists/*

COPY --from=//mcr.microsoft.com /usr/share/dotnet /opt/dotnet
COPY --from=build-env /app/output .

ENV PATH="${PATH}:/opt/dotnet"
ENV DOTNET_ROOT=/opt/dotnet

CMD ["dotnet", "Lampac.dll"]
