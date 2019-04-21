## Развертывание nginx в Alpine Linux Docker с помощью Dockerfile. Загрузка образа в Docker Hub.

### Установка Docker

Отключаем или настраиваем selinux
```
sed -i "s/SELINUX=enforcing/SELINUX=disabled/" /etc/selinux/config
```        
Устаналиваем docker
```
yum check-update
curl -fsSL https://get.docker.com/ | sh
systemctl start docker
systemctl enable docker
```

Добавляем пользователя Alexey в группу docker, команды будут выполняться от его имени (вместо root) 
```
usermod -aG docker Alexey
```

## Пример загрузки образа в Docker

Проверка docker после установки
```
docker run hello-world
```
Скачиваем образ centos
```
docker pull centos
```

## Загрузка и настройка образа с помощью Dockerfile

Далее непосредственно разворачиваем образ из Dockerfile.
Создаем каталог и копируем в него Dockerfile для установки nginx c конфигами nginx
```
mkdir -p /var/docker/alpine/nginx
cp -r /vagrant/install_nginx/* /var/docker/alpine/nginx
```
Создадим docker-образ из Dockerfile (abichutsky - тэг):  
```
docker build -t abichutsky/alpine-nginx /var/docker/alpine/nginx/
```
Смотрим информацию об образе
```
docker image
```
Запускаем (создаем) новый контейнер из развернутого образа abichutsky/alpine-nginx в интерактивном режиме
```
docker run -it abichutsky/alpine-nginx
```
Нажимаем комбинацию: ctrl+P, ctrl+Q, чтобы отсоединиться от консоли, не останавливая контейнер (соответственно при остановке, nginx будет не запущен)

Чтобы просмотреть список всех контейнеров
```
docker ps -a
```
Чтобы получить список недавно созданных контейнеров
```
docker ps -l
```
Чтобы остановить активный контейнер
```
docker stop container-id
```
Чтобы запустить остановленный контейнер
```
docker start container-id
```
Чтобы узнать id контейнера быстрым способом
```
docker ps
```
Посмотреть все слои образа
```
docker history
```

Открываем в браузере страницу nginx, который работает в докере по ссылке: http://172.17.0.2/ (в dockerfile указан порт 80) 

##Загружаем образ в Docker Hub

Предварительно регистрируемся на Docker-хабе. 

Авторизуемся с логином и паролем, указанным при регистрации
```
docker login -u abichutsky
```
Получив доступ к Docker Hub, можно загрузить новый образ
```
docker push abichutsky/alpine-nginx

The push refers to repository [docker.io/abichutsky/alpine-nginx]
3be52f07e99c: Pushed 
0504cb18521d: Pushed 
ad5f33ed0c1e: Pushed 
661eb7816ece: Pushed 
3b8af6f35d02: Pushed 
a464c54f93a9: Mounted from library/alpine 
latest: digest: sha256:732a455febaa55227421080fdf4858170266b11e261c6eecf4962c8930d391fb size: 1570

```
Скачать docker образ:
```
docker pull abichutsky/alpine-nginx

## Дополнительно:
- (Vagrant)[Vagrant]
- (cheatsheet по установке docker)[Docker.md]