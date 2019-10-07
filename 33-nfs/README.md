# 33. NFS и SAMBA

## Задание

Vagrant стенд для NFS или SAMBA на выбор.


`vagrant up` должен поднимать 2 виртуалки: сервер и клиент.  
На сервере должна быть расшарена директория.  
на клиента она должна автоматически монтироваться при старте (`fstab` или `autofs`).  
В шаре должна быть папка `upload` с правами на запись.  
Требования для NFS: NFSv3 по UDP, включенный firewall  


## Тестовый стенд

Запуск стенда `Vagrant`:
```bash
vagrant up
```
Виртуальные хосты c NFS:   
- **nfsserver**  
расшарен каталог: `/var/nfs_share`
- **client**  
`autofs` монтирует по требованию в: `/mnt/nfsserver/public`

## Проверка 

Проверка автомонтирования:

```bash
[Alexey@alexhome 33-nfs]$ vagrant ssh client
[vagrant@client ~]$ cd /mnt/nfsserver/public
[vagrant@client public]$ ls
upload
[vagrant@client public]$ cd upload/
[vagrant@client upload]$ mkdir testfolder
[vagrant@client upload]$ echo "test" > testfolder/testfile
[vagrant@client upload]$ ls -la testfolder/
total 4
drwxrwxr-x. 2 vagrant vagrant 22 Oct  6 19:39 .
drwxrwxrwx. 3 root    root    24 Oct  6 19:38 ..
-rw-rw-r--. 1 vagrant vagrant  5 Oct  6 19:39 testfile
[vagrant@client upload]$ df -hT
Filesystem               Type      Size  Used Avail Use% Mounted on
/dev/sda1                xfs        40G  2.9G   38G   8% /
devtmpfs                 devtmpfs  236M     0  236M   0% /dev
tmpfs                    tmpfs     244M     0  244M   0% /dev/shm
tmpfs                    tmpfs     244M  4.5M  240M   2% /run
tmpfs                    tmpfs     244M     0  244M   0% /sys/fs/cgroup
tmpfs                    tmpfs      49M     0   49M   0% /run/user/1000
nfsserver:/var/nfs_share nfs        40G  2.8G   38G   7% /mnt/nfsserver/public
```
Проверка политики `root_squash`:
```bash
[vagrant@client upload]$ sudo su
[root@client upload]# touch testfile2
[root@client upload]# ls -la
total 0
drwxrwxrwx. 3 root      root      41 Oct  6 19:44 .
dr-xr-xr-x. 3 root      root      20 Oct  6 19:34 ..
-rw-r--r--. 1 nfsnobody nfsnobody  0 Oct  6 19:44 testfile2
drwxrwxr-x. 2 vagrant   vagrant   22 Oct  6 19:39 testfolder
```