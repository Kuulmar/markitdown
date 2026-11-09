# Guia passo a passo – claude-stack no Windows

## Parte A – Rodar o instalador (uns 10–20 minutos)

1. Aperte a tecla **Windows** (a que tem o logo do Windows, perto do Ctrl esquerdo).
2. Digite: `powershell`
3. Aparece "Windows PowerShell". Clique nele **uma vez** com o botão **esquerdo**. Abre uma janela azul ou preta.
4. Clique dentro da janela. Copie a linha abaixo, cole na janela (clique com o botão **direito** do mouse dentro dela) e aperte **Enter**:

```powershell
irm https://raw.githubusercontent.com/kuulmar/markitdown/claude/bold-faraday-d6jlgb/windows-claude-stack/install.ps1 -OutFile $env:TEMP\cs.ps1; powershell -ExecutionPolicy Bypass -File $env:TEMP\cs.ps1
```

5. Se aparecer uma janela perguntando **"Deseja permitir que este aplicativo faça alterações?"**, clique em **Sim**.
6. Se o Claude pedir login (abre o navegador), clique em **Authorize/Autorizar** com sua conta Claude e volte para a janela.
7. Espere até aparecer **RESUMO**.
   - Verde "Tudo instalado" = pronto.
   - Vermelho = copie as linhas vermelhas e me mande.
8. No fim, o navegador abre sozinho em `http://localhost:20128/dashboard/api-manager`.

> Se o comando do passo 4 der erro **404**, o repositório é privado. Nesse caso: abra o GitHub no navegador, entre na pasta `windows-claude-stack` da branch `claude/bold-faraday-d6jlgb`, baixe `install.ps1` e `claude-stack.ps1` para a pasta **Downloads**, e rode na janela azul:
> `powershell -ExecutionPolicy Bypass -File $HOME\Downloads\install.ps1`

## Parte B – Painel do OmniRoute (navegador)

1. **Login:** no campo de senha digite `CHANGEME` e clique em **Login/Entrar**.
2. Se ele pedir para trocar a senha: invente uma nova, digite nos dois campos, clique em **Save/Salvar**. Anote essa senha.
3. **Conectar sua conta Claude:**
   1. No menu da esquerda, clique em **Providers**.
   2. Procure o cartão **Claude** (ou "Claude Code", ícone laranja). Clique nele.
   3. Clique em **Connect / Add account / OAuth** (o botão de conectar).
   4. Abre uma página da Anthropic. Clique em **Authorize/Autorizar**.
   5. Se aparecer um **código** para copiar: clique em **Copy**, volte na aba do OmniRoute, cole no campo e clique em **Submit/Salvar**.
   6. O cartão do Claude deve ficar com um ponto **verde / Connected**.
4. **Criar a chave:**
   1. No menu da esquerda, clique em **API Keys** (ou **API Manager**).
   2. Clique em **Create / New Key / + Add**.
   3. No nome, digite `claude-stack`. Clique em **Create/Criar**.
   4. Aparece a chave (começa geralmente com `sk-`). Clique em **Copy/Copiar**. Ela só aparece uma vez.

## Parte C – Salvar a chave e testar

1. Feche a janela azul antiga e abra uma **nova** (Parte A, passos 1–3).
2. Digite o comando abaixo, trocando `COLE_AQUI` pela chave (botão direito cola) e aperte **Enter**:

```powershell
claude-stack --set-key COLE_AQUI
```

3. Teste a cadeia completa:

```powershell
claude-stack -p "Responda só: cadeia OK"
```

A resposta esperada é **cadeia OK**. Na primeira vez pode levar até 2–3 minutos, porque o Headroom carrega os modelos dele.

## Uso no dia a dia

| Comando | O que faz |
|---|---|
| `claude-stack` | Sobe tudo e abre o Claude |
| `claude-stack --status` | Mostra o que está ligado |
| `claude-stack --stop` | Desliga OmniRoute e Headroom |

Logs ficam em `%USERPROFILE%\.config\claude-stack\` (`install.log`, `headroom.log`).

## Se der erro

| Mensagem | Solução |
|---|---|
| `claude-stack não é reconhecido` | Feche e abra uma janela nova do PowerShell |
| `Node incompativel` | Configurações > Aplicativos > desinstale "Node.js" > rode o instalador de novo |
| `OmniRoute nao respondeu` | `claude-stack --stop`, depois tente de novo |
| `Headroom nao respondeu` | Abra `headroom.log.err` e me mande o final |
| `401` / `invalid api key` | A chave está errada: crie outra no painel e repita `--set-key` |
