# girb (Generative IRB)

Ruby開発のためのAIアシスタント。IRB、Rails console、debug gemで動作します。

## 特徴

- **コンテキスト認識**: ローカル変数、インスタンス変数、実行時の状態を理解
- **ツール実行**: コード実行、オブジェクト検査、ファイル読み取りをAIが自律的に実行
- **自律的な調査**: 調査→実行→分析のサイクルをAIがループ
- **マルチ環境対応**: IRB、Rails console、debug gem (rdbg) で動作
- **プロバイダー非依存**: 任意のLLM（OpenAI、Anthropic、Gemini、Ollama等）を使用可能

## クイックスタート

```bash
# 1. インストール
gem install girb girb-ruby_llm

# 2. APIキーを設定
export GEMINI_API_KEY="your-api-key"  # または OPENAI_API_KEY, ANTHROPIC_API_KEY

# 3. ~/.girbrc を作成
```ruby
require 'girb-ruby_llm'
Girb.configure do |c|
  c.provider = Girb::Providers::RubyLlm.new(model: 'gemini-2.5-flash')
end
```

# 4. 実行
girb
```

質問を入力して **Ctrl+Space** を押すか、`qq <質問>` を使用します。

## 目次

1. [設定](#1-設定) - 全環境共通のセットアップ
2. [Rubyスクリプト (IRB)](#2-rubyスクリプト-irb) - 純粋なRubyでの使用
3. [Rails](#3-rails) - Rails consoleでの使用
4. [Debug Gem (rdbg)](#4-debug-gem-rdbg) - AIアシスタント付きステップ実行デバッグ

---

## 1. 設定

### インストール

```bash
gem install girb girb-ruby_llm
```

利用可能なプロバイダーgem:
- [girb-ruby_llm](https://github.com/rira100000000/girb-ruby_llm) - OpenAI、Anthropic、Gemini、Ollama等（推奨）
- [girb-gemini](https://github.com/rira100000000/girb-gemini) - Google Geminiのみ

### APIキー

使用するLLMプロバイダーのAPIキーを環境変数に設定:

```bash
export GEMINI_API_KEY="your-api-key"
# または OPENAI_API_KEY, ANTHROPIC_API_KEY など
```

詳細な設定方法（Ollama、その他のプロバイダー、高度なオプション）は、プロバイダーgemのドキュメントを参照してください:
- [girb-ruby_llm](https://github.com/rira100000000/girb-ruby_llm)
- [girb-gemini](https://github.com/rira100000000/girb-gemini)

### .girbrcの作成

プロジェクトルート（またはホームディレクトリ）に `.girbrc` ファイルを作成:

```ruby
# .girbrc
require 'girb-ruby_llm'

Girb.configure do |c|
  c.provider = Girb::Providers::RubyLlm.new(model: 'gemini-2.5-flash')
end
```

girbは以下の順序で `.girbrc` を探します:
1. カレントディレクトリ → 親ディレクトリ（ルートまで）
2. `~/.girbrc` にフォールバック

### モデルの例

```ruby
# Google Gemini
c.provider = Girb::Providers::RubyLlm.new(model: 'gemini-2.5-flash')

# OpenAI
c.provider = Girb::Providers::RubyLlm.new(model: 'gpt-5.2-2025-12-11')

# Anthropic
c.provider = Girb::Providers::RubyLlm.new(model: 'claude-opus-4-5')
```

### 設定オプション

```ruby
Girb.configure do |c|
  # 必須: LLMプロバイダー
  c.provider = Girb::Providers::RubyLlm.new(model: 'gemini-2.5-flash')

  # オプション: デバッグ出力
  c.debug = true

  # オプション: カスタムシステムプロンプト
  c.custom_prompt = <<~PROMPT
    破壊的操作の前に必ず確認してください。
  PROMPT
end
```

### 環境変数（フォールバック）

`.girbrc` に設定がない場合に使用:

| 変数 | 説明 |
|------|------|
| `GIRB_PROVIDER` | プロバイダーgem（例: `girb-ruby_llm`） |
| `GIRB_MODEL` | モデル名（例: `gemini-2.5-flash`） |
| `GIRB_DEBUG` | `1` でデバッグ出力有効化 |

### セッション永続化（オプション）

AIとの会話履歴をセッション間で保持できます。明示的にセッションIDを指定した場合のみ有効になります。

#### 有効化

`.girbrc` でセッションIDを設定:

```ruby
Girb.configure do |c|
  c.provider = Girb::Providers::RubyLlm.new(model: 'gemini-2.5-flash')
end

# セッション永続化を有効化（オプション）
Girb.debug_session = "my-project"
```

または、コード内で動的に設定:

```ruby
Girb.debug_session = "debug-user-auth"
debugger  # このセッションの会話が保存される
```

#### セッション管理コマンド

IRBまたはデバッグモードで使用:

```
qq session status  # 現在のセッション状態を表示
qq session list    # 保存されたセッション一覧
qq session clear   # 現在のセッションをクリア
```

#### 動作

- セッションは `.girb/sessions/<session_id>.json` に保存
- 7日以上アクセスのないセッションは自動削除
- 同じセッションIDで再開すると、過去の会話を引き継ぎ
- `get_session_history` ツールで過去の会話を参照可能

---

## 2. Rubyスクリプト (IRB)

### 使い方

`irb` の代わりに `girb` コマンドを使用:

```bash
girb
```

または、コード内に `binding.girb` を挿入:

```ruby
def problematic_method
  result = some_calculation
  binding.girb  # ここでAI付きIRBが起動
  result
end
```

### AIへの質問方法

**Ctrl+Space**: 質問を入力した後に押す

```
irb(main):001> なぜ失敗したの？[Ctrl+Space]
```

**qqコマンド**: qqメソッドを使用

```
irb(main):001> qq このメソッドの使い方を教えて
```

### 利用可能なツール (IRB)

| ツール | 説明 |
|--------|------|
| `evaluate_code` | Rubyコードを実行 |
| `inspect_object` | オブジェクトの詳細を検査 |
| `get_source` | メソッド/クラスのソースコードを取得 |
| `list_methods` | オブジェクトのメソッド一覧を取得 |
| `find_file` | ファイルを検索 |
| `read_file` | ファイル内容を読み取り |
| `get_session_history` | IRBセッション履歴を取得 |
| `continue_analysis` | 自律調査のためのコンテキスト更新をリクエスト |

### 使用例

```
irb(main):001> x = [1, 2, 3]
irb(main):002> 合計を求めるメソッドは？[Ctrl+Space]
`x.sum` で合計6が得られます。他にも `x.reduce(:+)` や `x.inject(0, :+)` が使えます。
```

---

## 3. Rails

### インストール

Gemfileに追加:

```ruby
group :development do
  gem 'girb'
  gem 'girb-ruby_llm'
end
```

```bash
bundle install
```

### 設定

Railsプロジェクトルートに `.girbrc` を作成。詳細は[設定](#1-設定)を参照。

### 使い方

`rails console` を実行するだけ - Railtieで自動的にgirbが読み込まれます:

```bash
rails console
```

### 追加ツール (Rails)

| ツール | 説明 |
|--------|------|
| `query_model` | ActiveRecordクエリを実行 |
| `model_info` | モデルのスキーマ情報を取得 |

### 使用例

```
irb(main):001> user = User.find(1)
irb(main):002> user.update(name: "test")
=> false
irb(main):003> なぜ更新に失敗したの？[Ctrl+Space]
`user.errors.full_messages` を確認したところ:
- "Email can't be blank"
更新時にemail属性が空になっています。
```

---

## 4. Debug Gem (rdbg)

AIアシスタント付きのステップ実行デバッグ。

### 設定

上記と同じ `.girbrc` を使用。

### Rubyスクリプトの場合

`require "debug"` と `require "girb"` を追加し、`debugger`ステートメントを使用:

**注意:** `require "debug"` は必ず `require "girb"` より先に記述してください。

```ruby
require "debug"
require "girb"

def calculate(x)
  result = x * 2
  debugger  # ここでAIアシスタント付きで停止
  result + 1
end

calculate(5)
```

rubyで実行:

```bash
ruby your_script.rb
```

### Railsの場合

debug gemより後にgirbを読み込むためinitializerを作成:

```ruby
# config/initializers/girb.rb
require "girb" if Rails.env.development? || Rails.env.test?
```

コード内で`debugger`ステートメントを使用:

```ruby
def show
  @user = User.find(params[:id])
  debugger  # ここでAIアシスタント付きで停止
end
```

### AIへの質問方法 (デバッグモード)

- **`qq <質問>`** - AIに質問
- **Ctrl+Space** - 現在の入力をAIに送信
- **日本語入力** - 非ASCII文字は自動的にAIにルーティング

```
(rdbg) qq ここでのresultの値は？
(rdbg) 次の行に進んで[Ctrl+Space]
```

### AIがデバッガコマンドを実行

AIがデバッガコマンドを自動で実行できます:

```
(rdbg) qq このループを実行して、xが1になるタイミングを教えて
```

AIは `step`、`next`、`continue`、`break` などを自動的に使用します。

### Ctrl+Cで中断

Ctrl+Cで長時間実行中のAI操作を中断できます。AIは進捗を要約します。

### 利用可能なツール (デバッグモード)

| ツール | 説明 |
|--------|------|
| `evaluate_code` | 現在のコンテキストでRubyコードを実行 |
| `inspect_object` | オブジェクトの詳細を検査 |
| `get_source` | メソッド/クラスのソースコードを取得 |
| `read_file` | ソースファイルを読み取り |
| `run_debug_command` | デバッガコマンドを実行 |
| `get_session_history` | デバッグセッション履歴を取得 |

### 使用例: 変数の追跡

```
(rdbg) qq このループでxの全ての値を追跡して、完了したら報告して

[AIがブレークポイントを設定、continueを実行、値を収集]

追跡したxの値: [7, 66, 85, 11, 53, 42, 99, 23]
ループが完了しました。
```

---

## カスタムプロバイダー

独自のLLMプロバイダーを実装:

```ruby
class MyProvider < Girb::Providers::Base
  def initialize(api_key:)
    @api_key = api_key
  end

  def chat(messages:, system_prompt:, tools:, binding: nil)
    # LLM APIを呼び出す
    response = call_my_llm(messages, system_prompt, tools)

    Girb::Providers::Base::Response.new(
      text: response.text,
      function_calls: response.tool_calls&.map { |tc| { name: tc.name, args: tc.args } }
    )
  end
end
```

---

## 動作要件

- Ruby 3.2.0以上
- IRB 1.6.0以上（IRB/Rails使用時）
- debug gem（rdbg使用時）
- LLMプロバイダーgem

## ライセンス

MIT License

## 貢献

バグ報告や機能リクエストは [GitHub Issues](https://github.com/rira100000000/girb/issues) へお願いします。
