# Используем базовый образ Debian 12
FROM debian:12

# Устанавливаем curl и другие зависимости, необходимые для Lampac и скачивания .NET
RUN apt-get update && apt-get install -y \
    curl \
    libc6 \
    libgcc1 \
    libgssapi-krb5-2 \
    libicu72 \
    libssl3 \
    libstdc++6 \
    zlib1g \
    build-essential

# 2. Скачиваем .NET 8 SDK (стабильная версия) бинарно по полной ссылке
# Ссылка актуальна на данный момент, но может измениться в будущем.
RUN curl -L https://download.visualstudio.microsoft.com -o dotnet.tar.gz \
    && mkdir -p /opt/dotnet \
    && tar -zxf dotnet.tar.gz -C /opt/dotnet \
    && rm dotnet.tar.gz \
    && ln -s /opt/dotnet/dotnet /usr/bin/dotnet

# Устанавливаем рабочую директорию
WORKDIR /app

# Копируем файлы проекта и публикуем приложение
COPY . .
RUN dotnet publish -c Release -o output

# Финальный образ для запуска (используем уже установленный рантайм)
FROM debian:12
WORKDIR /app
COPY --from=0 /opt/dotnet /opt/dotnet
COPY --from=0 /app/output .

# Добавляем необходимые библиотеки для запуска (если их нет в базовом образе)
# Это может потребоваться, если приложение использует графические или другие специфические библиотеки
RUN apt-get update && apt-get install -y \
    libc6 \
    libgcc1 \
    libgssapi-krb5-2 \
    libicu72 \
    libssl3 \
    libstdc++6 \
    zlib1g \
    fontconfig \
    libfreetype6 \
    libpng16-16 \
    libxrender1 \
    libfontconfig1 \
    libasound2 \
    libatk1.0-0 \
    libglib2.0-0 \
    libatk-bridge2.0-0 \
    libxdmcp6 \
    libxcb1 \
    libxau6

# Указываем команду запуска приложения
# Убедитесь, что имя вашей DLL-ки совпадает с Lampac.dll
CMD ["/opt/dotnet/dotnet", "Lampac.dll"]
