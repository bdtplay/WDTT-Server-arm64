# WDTT Server + Xray (ARM64) для MikroTik RouterOS v7

Лёгкий и полностью автономный Docker-образ на базе **Alpine Linux (`linux/arm64`)** с предустановленным сервером **WDTT** (поддержка режимов DTLS, RAW, CSQTT) и ядром **Xray-core (ARM64)** с прозрачным перехватом трафика. 

Образ оптимизирован специально для роутеров MikroTik с архитектурой ARM64

---

## ✨ Особенности сборки

* **Минимальное потребление ОЗУ:** настроены лимиты сборщика мусора Go (`GOMEMLIMIT=120MiB`, `GOGC=50`). Реальное потребление памяти (`RSS`) процесса `wdtt-app` составляет **~60–75 МБ**.
* **Все протоколы «из коробки»:** настроен автоматический NAT (`MASQUERADE`) и MSS Clamping без привязки к имени интерфейса `eth0` — работают как классический **WDTT (`10.66.66.0/24`)**, так и скоростной режим **RAW (`10.70.0.0/16`)**.
* **Интеграция с Xray-core ARM64:** бинарник Xray вшит в образ, привязан к прозрачному перехвату TCP (`PREROUTING REDIRECT` на порт `12345`) и полностью управляется из веб-панели.
* **Сохранение состояния служб:** при остановке Xray через веб-панель состояние запоминается и не сбрасывается после перезагрузки роутера или контейнера.
* **Полная совместимость веб-панели с Alpine:** встроенный эмулятор `systemctl` обеспечивает корректное отображение статусов, аптайма и работу кнопок перезапуска служб без падения контейнера.

---

## 🚀 Установка на MikroTik (RouterOS v7)

### 1. Подготовка сети и реестра контейнеров
Создайте виртуальный интерфейс `veth` (в примере используется адрес `192.168.88.100` в основном бридже `bridge`) и укажите папку для временных файлов на внешнем накопителе:

```routeros
/interface/veth/add name=qWDTT address=192.168.88.100/24 gateway=192.168.88.1
/interface/bridge/port/add bridge=bridge interface=qWDTT
/container/config/set registry-url=https://ghcr.io tmpdir=/usb1/pull
```

### 2. Загрузка и запуск контейнера
Скачайте готовый образ из GitHub Container Registry:

```routeros
/container/add remote-image=ghcr.io/bdtplay/wdtt-server-arm64:latest interface=qWDTT root-dir=/usb1/docker/qWDTT logging=no start-on-boot=yes
```

*(Опционально) Если хотите задать свой пароль для первого VPN-пользователя вместо стандартного `StartPass123`, добавьте переменную окружения перед запуском:*
```routeros
/container/envs/add name=wdtt-env key=START_PASSWORD value="ВашСложныйПароль"
/container/set 0 envlist=wdtt-env
```

Дождитесь окончания распаковки (`stopped`) и запустите контейнер:
```routeros
/container/start 0
```

### 3. Проброс портов в Firewall (WAN -> Контейнер)
Откройте внешние UDP-порты для подключения клиентов (`56000` — DTLS, `56003` — RAW, `46000` — CSQTT):

```routeros
/ip/firewall/nat/add chain=dstnat action=dst-nat to-addresses=192.168.88.100 to-ports=56000 protocol=udp dst-port=56000 in-interface-list=WAN comment="WDTT DTLS"
/ip/firewall/nat/add chain=dstnat action=dst-nat to-addresses=192.168.88.100 to-ports=56003 protocol=udp dst-port=56003 in-interface-list=WAN comment="WDTT RAW"
/ip/firewall/nat/add chain=dstnat action=dst-nat to-addresses=192.168.88.100 to-ports=46000 protocol=udp dst-port=46000 in-interface-list=WAN comment="WDTT CSQTT"

/ip/firewall/filter/add chain=forward action=accept connection-nat-state=dstnat in-interface-list=WAN protocol=udp dst-port=46000,56000,56003 place-before=1 comment="Allow WDTT NAT"
```

---

## 🌐 Доступ к веб-панели

Откройте в браузере из локальной сети (обязательно по протоколу `http://` и со слешем `/` в конце):

* **URL:** `http://192.168.88`
* **Логин по умолчанию:** `admin`
* **Пароль по умолчанию:** `wdtt` *(рекомендуется сразу сменить в разделе «Настройки»)*
* **Стартовый пользователь VPN:** `StartPass123`

---

## 🔄 Обновление версий компонентов

Образ собирается автоматически через **GitHub Actions** при каждом изменении файлов в репозитории:
* Чтобы обновить версию сервера **WDTT**, измените `ARG WDTT_VER=...` в файле `Dockerfile`.
* Ядро **Xray-core (`Xray-linux-arm64-v8a`)** автоматически подтягивается из последнего стабильного релиза при каждой пересборке образа.
