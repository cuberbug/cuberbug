#!/usr/bin/env fish
#
# ./scripts/update-webui.fish
#
# Обновляет и перезапускает контейнер Open WebUI.
# Скрипт:
#   - проверяет наличие Docker
#   - проверяет доступность Docker daemon
#   - останавливает и удаляет старый контейнер
#   - скачивает свежий образ
#   - запускает новый контейнер
#   - выводит понятные сообщения об ошибках
#

# =========================
# Настройки
# =========================

set CONTAINER_NAME "open-webui"
set IMAGE_NAME "ghcr.io/open-webui/open-webui:main"
set DATA_VOLUME "open-webui"

# =========================
# Цвета и оформление
# =========================

set c_red    (set_color red)
set c_green  (set_color green)
set c_yellow (set_color yellow)
set c_blue   (set_color blue)

set c_bold   (set_color --bold)

set c_normal (set_color normal)

# =========================
# Вспомогательные функции
# =========================

function info
  printf "%s[INFO]%s  %s\n" "$c_blue" "$c_normal" "$argv"
end

function success
  printf "%s[ OK ]%s  %s\n\n" "$c_green" "$c_normal" "$argv"
end

function warn
  printf "%s[WARN]%s  %s\n" "$c_yellow" "$c_normal" "$argv"
end

function error_exit
  printf "%s[FAIL]%s  %s\n" "$c_red" "$c_normal" "$argv" >&2
  exit 1
end

# =========================
# Проверки окружения
# =========================

if not command -q docker
  error_exit "Docker не установлен или недоступен в PATH."
end

# Проверка прав доступа: пользователь должен быть root или состоять в группе docker
if test (id -u) -ne 0; and not id -nG | grep -qw docker
  warn "Текущий пользователь не входит в группу 'docker'."
  printf "Запустите скрипт от root или добавьте пользователя в группу: "
  printf "%ssudo usermod -aG docker \$USER%s\n" "$c_bold" "$c_normal"
  exit 1
end

if not docker info >/dev/null 2>&1
  error_exit "Docker daemon недоступен. Проверьте, запущен ли docker.service."
end

# =========================
# Остановка старого контейнера
# =========================

if docker container inspect $CONTAINER_NAME >/dev/null 2>&1
  info "Найден существующий контейнер '$CONTAINER_NAME'."

  info "Останавливаю контейнер..."
  if docker stop $CONTAINER_NAME >/dev/null
    success "Контейнер остановлен."
  else
    error_exit "Не удалось остановить контейнер."
  end

  info "Удаляю контейнер..."
  if docker rm $CONTAINER_NAME >/dev/null
    success "Контейнер удалён."
  else
    error_exit "Не удалось удалить контейнер."
  end
else
  warn "Контейнер '$CONTAINER_NAME' не найден. Пропускаю удаление."
end

# =========================
# Обновление образа
# =========================

info "Скачиваю свежий образ:"
printf ">>>>>>  %s%s%s\n" "$c_bold" "$IMAGE_NAME" "$c_normal"

if docker pull $IMAGE_NAME
  success "Образ успешно обновлён."
else
  error_exit "Ошибка при загрузке образа."
end

# =========================
# Запуск контейнера
# =========================

info "Запускаю новый контейнер..."

docker run -d \
  --network=host \
  -v $DATA_VOLUME:/app/backend/data \
  -e OLLAMA_BASE_URL=http://127.0.0.1:11434 \
  --name $CONTAINER_NAME \
  --restart always \
  $IMAGE_NAME >/dev/null

if test $status -ne 0
  error_exit "Не удалось запустить контейнер."
end

# =========================
# Проверка состояния
# =========================

# Ждём запуск контейнера
for i in (seq 10)
  set -l CONTAINER_STATUS (docker inspect -f '{{.State.Status}}' $CONTAINER_NAME 2>/dev/null)

  if test "$CONTAINER_STATUS" = "running"
    break
  end

  sleep 1
end

set CONTAINER_STATUS (docker inspect -f '{{.State.Status}}' $CONTAINER_NAME 2>/dev/null)

if test "$CONTAINER_STATUS" = "running"
  success "Контейнер успешно запущен."

  printf "%s Open WebUI доступен по адресу:%s\n" $c_green $c_normal
  printf "    http://localhost:8080\n"
  printf "\n"
  printf "%s Полезные команды:%s\n" $c_blue $c_normal
  printf "    docker logs -f %s\n" $CONTAINER_NAME
  printf "    docker ps\n"
else
  error_exit "Контейнер создан, но не запущен корректно. Проверьте логи:"
  printf "docker logs %s\n" $CONTAINER_NAME
end
