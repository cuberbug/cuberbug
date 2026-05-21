#!/usr/bin/env fish
#
# ./scripts/fix-v2rayn.fish
#
# Временное решение для исправления маршрутизации в TUN-режиме v2rayN.
# Скрипт автоматически находит текущий сетевой интерфейс и шлюз по умолчанию,
# после чего принудительно направляет трафик до VPS в обход TUN-таблицы.
#

echo "[INFO] Запуск скрипта исправления маршрутов v2rayN"

# 1. Сбор информации о текущем сетевом подключении
# Получаем всю строку дефолтного маршрута
# (например: "default via 192.168.1.1 dev wlo1 proto dhcp src 192.168.1.42 metric 600")
set default_route (ip -4 route show default)

if test -z "$default_route"
    echo "[FAIL] Не найден дефолтный маршрут в системе. Проверьте подключение к сети."
    exit 1
end

# Извлекаем IP-адрес шлюза (следующий за 'via')
set gateway_ip (echo $default_route | string match -r 'via \S+' | string replace 'via ' '')
# Извлекаем имя активного интерфейса (следующее за 'dev')
set net_interface (echo $default_route | string match -r 'dev \S+' | string replace 'dev ' '')

if test -z "$gateway_ip"; or test -z "$net_interface"
    echo "[FAIL] Не удалось распарсить параметры сети."
    echo "Строка маршрута: $default_route"
    exit 1
end


echo "[INFO] Сеть определена успешно:"
echo "       • Рабочий интерфейс: $net_interface"
echo "       • Дефолтный шлюз:    $gateway_ip"
echo "---"

# Список IP-адресов серверов которые нужно направить напрямую
# (хардкод)
set target_ips 144.31.16.39 94.131.100.184
set routing_table 2022
set success true

# 2. Применение маршрутов
for ip in $target_ips
    echo "Добавление правила для $ip/32 через $gateway_ip ($net_interface)..."

    if sudo ip route replace "$ip/32" via $gateway_ip dev $net_interface table $routing_table
        echo "[ OK ] Маршрут для $ip обновлен."
    else
        echo "[FAIL] Не удалось добавить маршрут для $ip."
        set success false
    end
end

# 3. Итоговый статус
echo "---"
if test "$success" = true
    echo "[ OK ] Все маршруты v2rayN успешно скорректированы."
    exit 0
else
    echo "[FAIL] Некоторые маршруты не были применены. Проверьте логи выше."
    exit 1
end
