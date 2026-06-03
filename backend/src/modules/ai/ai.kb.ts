import { Injectable } from '@nestjs/common';

/**
 * Lightweight knowledge base for the `search_kb` read-only tool (§11.7 — "RAG облегчённо/опционально").
 *
 * Deliberately not a vector store: a small curated FAQ with keyword scoring is enough to ground
 * support answers for the demo and keeps the backend dependency-free. Swap `search` for a real
 * retriever (embeddings + pgvector) later without touching the tool contract.
 */

export interface KbEntry {
  id: string;
  title: string;
  body: string;
  tags: string[];
}

export interface KbHit {
  id: string;
  title: string;
  snippet: string;
  score: number;
}

const ENTRIES: KbEntry[] = [
  {
    id: 'kb-transfer-sbp',
    title: 'Переводы по СБП',
    body: 'Переводы по номеру телефона через СБП — мгновенно и без комиссии до лимита СБП. В приложении: «Переводы» → по телефону → выбрать банк получателя → подтвердить Face ID.',
    tags: ['перевод', 'сбп', 'телефон', 'комиссия'],
  },
  {
    id: 'kb-card-freeze',
    title: 'Заморозка и разблокировка карты',
    body: 'Карту можно мгновенно заморозить в разделе «Карты» → выбрать карту → «Заморозить». Заморозка обратима: разблокировка там же. Для разовых онлайн-покупок выпустите одноразовую карту.',
    tags: ['карта', 'заморозка', 'блокировка', 'безопасность'],
  },
  {
    id: 'kb-deposit',
    title: 'Вклады и стейкинг',
    body: 'В хабе «Приумножить» рядом рублёвые вклады (ставка, срок, капитализация, страхование АСВ) и крипто-стейкинг (APY, период блокировки, рыночный риск). Открытие требует подтверждения.',
    tags: ['вклад', 'депозит', 'стейкинг', 'процент', 'апи', 'apy', 'накопления'],
  },
  {
    id: 'kb-crypto-limits',
    title: 'Лимиты и статус инвестора',
    body: 'Операции с криптовалютой зависят от статуса инвестора. Для неквалифицированных инвесторов действует годовой лимит; доступны BTC, ETH и стейблкоины. Анонимные монеты запрещены.',
    tags: ['крипто', 'лимит', 'инвестор', 'квалифицированный', 'комплаенс'],
  },
  {
    id: 'kb-digital-ruble',
    title: 'Цифровой рубль',
    body: 'Цифровой рубль — отдельный кошелёк-счёт. Можно открыть, пополнить, платить по универсальному QR и переводить C2C. В демо — реалистичная симуляция двухуровневой модели ЦБ.',
    tags: ['цифровой рубль', 'кошелёк', 'qr', 'цфр'],
  },
  {
    id: 'kb-support-human',
    title: 'Связаться с оператором',
    body: 'В любой момент можно подключить живого оператора: попросите «оператора» или «человека», и копилот создаст обращение в поддержку. Срочные вопросы по безопасности — приоритетная очередь.',
    tags: ['оператор', 'человек', 'поддержка', 'эскалация', 'помощь'],
  },
  {
    id: 'kb-biz-tax-regimes',
    title: 'Налоговые режимы для бизнеса (УСН)',
    body: 'УСН «Доходы» — ставка 6% со всей выручки, простой учёт, выгоден при низкой доле расходов. УСН «Доходы минус расходы» — ставка 15% с прибыли, выгоднее, когда расходы превышают ~60–70% выручки. Сменить режим можно с начала календарного года (заявление до 31 декабря). AI-бухгалтер оценит эффект для вашей структуры расходов; точный расчёт зависит от учётной политики.',
    tags: ['налог', 'усн', 'режим', 'оптимизация', 'доходы', 'расходы', 'бизнес', 'ставка'],
  },
  {
    id: 'kb-biz-cashflow-gap',
    title: 'Кассовый разрыв и прогноз денежного потока',
    body: 'Кассовый разрыв — момент, когда денег на счёте не хватает на обязательные платежи, даже если бизнес прибыльный. AI-бухгалтер строит прогноз денежного потока на 90 дней и заранее предупреждает о разрыве с суммой и датой. Закрыть разрыв помогают: ускорение оплаты дебиторки (неоплаченных счетов), перенос крупных платежей, овердрафт/кредитная линия, рассрочка с поставщиком.',
    tags: ['кассовый разрыв', 'прогноз', 'кэшфлоу', 'денежный поток', 'ликвидность', 'дебиторка', 'овердрафт', 'бизнес'],
  },
  {
    id: 'kb-biz-invoices',
    title: 'Счета и оплата контрагентам',
    body: 'Бизнес может выставлять счета клиентам (входящий платёж/дебиторка) и оплачивать счета поставщикам (исходящий платёж). AI-бухгалтер готовит черновик счёта или оплаты — действие подтверждается биометрией. Крупные платежи уходят на вторую подпись (2-of-N) по правилам ролей команды.',
    tags: ['счёт', 'инвойс', 'поставщик', 'контрагент', 'оплата', 'дебиторка', 'подпись', 'бизнес'],
  },
];

@Injectable()
export class AiKnowledgeBase {
  /** Keyword-scored search; returns the top `limit` entries with a short snippet. */
  search(query: string, limit = 3): KbHit[] {
    const terms = tokenize(query);
    if (terms.length === 0) return [];

    const scored = ENTRIES.map((e) => ({ entry: e, score: score(e, terms) }))
      .filter((s) => s.score > 0)
      .sort((a, b) => b.score - a.score)
      .slice(0, limit);

    return scored.map(({ entry, score }) => ({
      id: entry.id,
      title: entry.title,
      snippet: entry.body.length > 220 ? entry.body.slice(0, 217) + '…' : entry.body,
      score,
    }));
  }
}

function tokenize(s: string): string[] {
  return s
    .toLowerCase()
    .replace(/[^\p{L}\p{N}\s]/gu, ' ')
    .split(/\s+/)
    .filter((t) => t.length >= 3);
}

function score(entry: KbEntry, terms: string[]): number {
  const hay = `${entry.title} ${entry.body} ${entry.tags.join(' ')}`.toLowerCase();
  let s = 0;
  for (const t of terms) {
    if (entry.tags.some((tag) => tag.includes(t) || t.includes(tag))) s += 3;
    else if (hay.includes(t)) s += 1;
  }
  return s;
}
