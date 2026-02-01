# girb (Generative IRB)

IRBセッションに組み込まれたAIアシスタント。実行中のコンテキストを理解し、デバッグや開発を支援します。

## 特徴

- **コンテキスト認識**: ローカル変数、インスタンス変数、selfオブジェクトなどを自動的に把握
- **例外キャプチャ**: 直前の例外を自動キャプチャ - エラー後に「なぜ失敗した？」と聞くだけでOK
- **セッション履歴の理解**: IRBでの入力履歴を追跡し、会話の流れを理解
- **ツール実行**: コードの実行、オブジェクトの検査、ソースコードの取得などをAIが自律的に実行
- **多言語対応**: ユーザーの言語を検出し、同じ言語で応答
- **カスタマイズ可能**: 独自のプロンプトを追加して、プロジェクト固有の指示を設定可能
- **プロバイダー非依存**: Gemini、OpenAI、または独自のLLMプロバイダーを実装可能

## インストール

Gemfileに追加:

```ruby
gem 'girb'
gem 'girb-gemini'  # または他のプロバイダー
```

そして実行:

```bash
bundle install
```

または直接インストール:

```bash
gem install girb girb-gemini
```

## セットアップ

### Geminiを使用する場合（推奨）

APIキーを環境変数に設定:

```bash
export GEMINI_API_KEY=your-api-key
```

`~/.irbrc` に追加:

```ruby
require 'girb-gemini'
```

これだけです！`GEMINI_API_KEY`が設定されていれば、Geminiプロバイダーが自動設定されます。

### 他のプロバイダーを使用する場合

独自のプロバイダーを実装するか、コミュニティのプロバイダーを使用:

```ruby
require 'girb'

Girb.configure do |c|
  c.provider = MyCustomProvider.new(api_key: "...")
end
```

実装の詳細は[カスタムプロバイダー](#カスタムプロバイダー)を参照してください。

## 使い方

### 起動方法

```bash
girb
```

または `~/.irbrc` に以下を追加すると、通常の `irb` コマンドでも使えます:

```ruby
require 'girb-gemini'
```

### binding.girbでデバッグ

コード内に `binding.girb` を挿入:

```ruby
def problematic_method
  result = some_calculation
  binding.girb  # ここでAI付きIRBが起動
  result
end
```

### AIへの質問方法

#### 方法1: Ctrl+Space

入力後に `Ctrl+Space` を押すと、その入力がAIへの質問として送信されます。

```
irb(main):001> このエラーの原因は？[Ctrl+Space]
```

#### 方法2: qqコマンド

```
irb(main):001> qq "このメソッドの使い方を教えて"
```

## 設定オプション

`~/.irbrc` に追加:

```ruby
require 'girb-gemini'

Girb.configure do |c|
  # プロバイダー設定（girb-geminiは自動設定されますが、カスタマイズ可能）
  c.provider = Girb::Providers::Gemini.new(
    api_key: ENV['GEMINI_API_KEY'],
    model: 'gemini-2.5-flash'
  )

  # デバッグ出力（デフォルト: false）
  c.debug = true

  # カスタムプロンプト（オプション）
  c.custom_prompt = <<~PROMPT
    本番環境です。破壊的操作の前に必ず確認してください。
  PROMPT
end
```

### コマンドラインオプション

```bash
girb --debug    # デバッグ出力を有効化
girb -d         # 同上
girb --help     # ヘルプを表示
```

## AIが使用できるツール

| ツール | 説明 |
|--------|------|
| `evaluate_code` | IRBのコンテキストでRubyコードを実行 |
| `inspect_object` | オブジェクトの詳細を検査 |
| `get_source` | メソッドやクラスのソースコードを取得 |
| `list_methods` | オブジェクトのメソッド一覧を取得 |
| `find_file` | プロジェクト内のファイルを検索 |
| `read_file` | ファイルの内容を読み取り |
| `session_history` | IRBセッションの履歴を取得 |

### Rails環境での追加ツール

| ツール | 説明 |
|--------|------|
| `query_model` | ActiveRecordモデルへのクエリ実行 |
| `model_info` | モデルのスキーマ情報を取得 |

## カスタムプロバイダー

独自のLLMプロバイダーを実装:

```ruby
class MyProvider < Girb::Providers::Base
  def initialize(api_key:)
    @api_key = api_key
  end

  def chat(messages:, system_prompt:, tools:)
    # messages: { role: :user/:assistant/:tool_call/:tool_result, content: "..." } の配列
    # tools: { name: "...", description: "...", parameters: {...} } の配列

    # LLM APIを呼び出す
    response = call_my_llm(messages, system_prompt, tools)

    # Responseオブジェクトを返す
    Girb::Providers::Base::Response.new(
      text: response.text,
      function_calls: response.tool_calls&.map { |tc| { name: tc.name, args: tc.args } }
    )
  end
end

Girb.configure do |c|
  c.provider = MyProvider.new(api_key: ENV['MY_API_KEY'])
end
```

## 使用例

### デバッグ支援

```
irb(main):001> user = User.find(1)
irb(main):002> user.update(name: "test")
=> false
irb(main):003> なぜ更新に失敗したの？[Ctrl+Space]
`user.errors.full_messages` を確認したところ、バリデーションエラーが発生しています:
- "Email can't be blank"
nameの更新時にemailが空になっている可能性があります。
```

### コードの理解

```
irb(main):001> このプロジェクトでUserモデルはどこで定義されてる？[Ctrl+Space]
app/models/user.rb で定義されています。
```

### パターン認識

```
irb(main):001> a = 1
irb(main):002> b = 2
irb(main):003> c = 3以降も続けるとzはいくつ？[Ctrl+Space]
パターン a=1, b=2, c=3... を続けると、z=26 になります。
```

## 動作要件

- Ruby 3.2.0以上
- IRB 1.6.0以上
- LLMプロバイダー（例: girb-gemini）

## ライセンス

MIT License

## 貢献

バグ報告や機能リクエストは [GitHub Issues](https://github.com/rira100000000/girb/issues) へお願いします。
