# DevOS Forge — Prompt Zero

> Leia o `00_PROMPT_ZERO.md` e siga integralmente as instruções dele.

Este arquivo define o contrato operacional mínimo para qualquer humano ou agente que trabalhe neste repositório.

## 1. Missão

DevOS Forge é a infraestrutura Git self-hosted privada do ecossistema DevOS.

O objetivo imediato é obter independência operacional de uma forge externa para:

- hospedagem de repositórios Git;
- clone / fetch / pull / push;
- branches, tags e releases;
- issues e pull requests;
- CI/CD;
- runners;
- webhooks e API;
- integração com DevOS.

O objetivo **não** é recriar GitHub feature-for-feature.

## 2. Estratégia atual

A implementação inicial usa **Forgejo** como engine madura de forge.

A visão de longo prazo é evoluir para uma camada agent-native que conecte:

```text
intenção humana
  -> PDS
  -> escolhas explícitas
  -> PBI
  -> PBP
  -> execução por agentes
  -> evidências
  -> Git
```

Não construir uma engine de forge própria antes que uso real demonstre claramente a necessidade.

## 3. Separação de responsabilidades

Manter estes limites:

```text
Git         = controle de versão
Forgejo     = forge / colaboração / CI base
DevOS       = intenção, orquestração, políticas e execução agentic
DevOS Forge = sistema resultante da integração dessas camadas
```

Não acoplar o núcleo do DevOS diretamente a detalhes internos do Forgejo quando uma abstração de provider puder preservar portabilidade.

## 4. Regra de intenção humana

A máquina pode:

- descobrir estado;
- coletar fatos;
- validar consistência;
- gerar alternativas;
- formalizar decisões já tomadas;
- executar planos autorizados.

A máquina **não pode inventar desejo humano** quando houver uma escolha material de produto, arquitetura, segurança, custo ou operação.

Quando uma escolha material ainda não existir, registrar como `OPEN` ou `TBD` em vez de silenciosamente decidir.

## 5. Fonte de verdade

Antes de alterar arquitetura, infraestrutura ou roadmap, ler no mínimo:

1. `README.md`
2. `docs/PROJECT-STATE.md`
3. `docs/DECISIONS.md`
4. `docs/ARCHITECTURE.md`
5. `docs/ROADMAP.md`

`docs/PROJECT-STATE.md` é o checkpoint operacional atual.

`docs/DECISIONS.md` registra decisões duráveis e seu racional.

## 6. Mudanças

Preferir mudanças coesas e verificáveis em vez de microalterações dispersas.

Para mudanças relevantes:

1. identificar o objetivo;
2. verificar decisões existentes;
3. declarar hipóteses;
4. executar a menor mudança completa;
5. validar;
6. atualizar documentação somente quando o estado do projeto realmente mudou.

## 7. Segurança e operações destrutivas

Nunca:

- expor credenciais, tokens ou chaves privadas;
- armazenar segredos em texto puro no repositório;
- apagar repositórios, volumes, backups ou dados de produção sem autorização explícita;
- desabilitar backup, autenticação ou proteção de acesso apenas para simplificar implantação;
- assumir que um backup existe sem verificar restauração.

Operações destrutivas devem ser reversíveis ou ter plano de recuperação validado.

## 8. Migração

A saída do GitHub deve ser gradual e testável.

A ordem preferida é:

```text
GitHub principal + Forgejo em validação
        ->
Forgejo principal + GitHub como mirror
        ->
Forgejo principal + GitHub opcional
```

Não migrar todos os repositórios de uma só vez antes de validar o circuito completo com um repositório piloto.

## 9. Critério de sucesso inicial

A primeira versão útil de DevOS Forge deve permitir que um projeto real complete, sem depender do GitHub:

```text
clone
-> branch
-> commit
-> push
-> pull request
-> CI
-> runner
-> merge
-> release/deploy
```

Somente depois desse circuito estar estável devemos aprofundar recursos agent-native.