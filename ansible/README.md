# ansible — перенесено в wiki/

Полная документация playbook в wiki:

- [20 — Ansible overview](../wiki/20-ansible.md) — запуск, теги, валидация
- [21 — Applications](../wiki/21-ansible-applications.md) — что именно ставится
- [CLAUDE.md](../CLAUDE.md) — правило валидации `--syntax-check` перед коммитом

## Быстрый запуск

```bash
cd ~/mr/workspace/my_os/ansible
sudo ansible-playbook -i inventory.ini site.yml

# Отдельное приложение
sudo ansible-playbook -i inventory.ini site.yml --tags vscode
```
