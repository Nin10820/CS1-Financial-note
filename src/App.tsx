import { Suspense, lazy, useCallback, useState } from "react";
import Today from "./screens/Today";
import type { Range } from "./screens/TodayHeader";
import NoteEditor from "./screens/NoteEditor";
import Due from "./screens/Due";
import BillSheet from "./screens/BillSheet";
import AddBill from "./screens/AddBill";
import { ComingUp, Installments, PaidHistory } from "./screens/DueSheets";
import Assistant, { type AssistantOpen } from "./screens/Assistant";
import AI from "./screens/AI";
import Finance from "./screens/Finance";
import Profile from "./screens/Profile";
import type { ScanPrefill } from "./screens/Scan";
import Template from "./screens/Template";
import TabBar, { ActionMenu, type Tab } from "./components/TabBar";
import { today } from "./lib/format";
import { dueIn, ym } from "./lib/bills";
import { uid, useStore } from "./lib/store";
import "./screens/screens.css";
import "./screens/note.css";
import "./screens/due.css";
import "./styles/press.css";

type Screen = "transaction" | "due" | "installments" | "finance" | "ai";
type Overlay =
  | { kind: "assistant"; opts: AssistantOpen }
  | { kind: "template"; id?: string; prefill?: ScanPrefill }
  | { kind: "editor" }
  | { kind: "scan" }
  | { kind: "profile" }
  | { kind: "bill"; id: string }
  | { kind: "add-bill" }
  | { kind: "coming-up" }
  | { kind: "paid-history" }
  | null;

// The QR reader is heavy; load it the first time Scan opens.
const Scan = lazy(() => import("./screens/Scan"));

const TAB_OF: Record<Screen, Tab> = {
  transaction: "expense",
  due: "due",
  installments: "due",
  finance: "finance",
  ai: "ai",
};

export default function App() {
  const store = useStore();
  const [screen, setScreen] = useState<Screen>("transaction");
  const [day, setDay] = useState(today);
  const [range, setRange] = useState<Range>("day");
  const [month, setMonth] = useState(() => ym(today()));
  const [hidden, setHidden] = useState(() => store.prefs.hideOnOpen);
  const [assetsHidden, setAssetsHidden] = useState(
    () => store.prefs.hideAssets || store.prefs.hideOnOpen,
  );
  const [overlay, setOverlay] = useState<Overlay>(null);
  const [menuOpen, setMenuOpen] = useState(false);
  const [addAsset, setAddAsset] = useState(0);

  const close = useCallback(() => setOverlay(null), []);
  const go = (s: Screen) => {
    setOverlay(null);
    setMenuOpen(false);
    setScreen(s);
    window.scrollTo(0, 0);
  };
  const assistant = (opts: AssistantOpen = {}) => {
    setMenuOpen(false);
    setOverlay({ kind: "assistant", opts });
  };
  const openDay = (d: string) => {
    setDay(d);
    setRange("day");
    go("transaction");
  };
  const onTab = (t: Tab) => go(t === "expense" ? "transaction" : t);

  // + : Due adds a bill, Finance an asset; Today and AI open Talk / Template / Scan.
  const tab = TAB_OF[screen];
  const plusLabel =
    tab === "due"
      ? "Add a bill"
      : tab === "finance"
        ? "Add an asset"
        : menuOpen
          ? "Close"
          : "New";
  const onPlus = () => {
    if (tab === "due") setOverlay({ kind: "add-bill" });
    else if (tab === "finance") setAddAsset((n) => n + 1);
    else setMenuOpen((m) => !m);
  };

  // The spending is recorded on the day the bill is ticked off — the day the money actually left.
  const toggleBill = (
    id: string,
    paid: boolean,
    amount?: number,
    m = month,
  ) => {
    const bill = store.bills.find((b) => b.id === id);
    if (bill) store.setBillPaid(bill, m, paid, today(), amount);
  };

  const sources = store.assets
    .filter((a) => a.kind === "available" || a.kind === "aside")
    .map((a) => a.name);

  return (
    <div className="app">
      {screen === "transaction" && (
        <Today
          day={day}
          today={today()}
          onDayChange={setDay}
          range={range}
          onRange={setRange}
          entries={store.entries}
          notes={store.notes}
          name={store.name}
          hidden={hidden}
          onToggleHidden={() => setHidden((h) => !h)}
          onOpenEntry={(id) => setOverlay({ kind: "template", id })}
          onDeleteEntry={store.removeEntry}
          onOpenNote={(d) => {
            setDay(d);
            setOverlay({ kind: "editor" });
          }}
          onIdea={(idea) =>
            idea === "due"
              ? go("due")
              : assistant(
                  idea === "decisions"
                    ? {
                        notice:
                          "Tell me what's on your mind — or write what you spent and I'll split it into lines.",
                      }
                    : {},
                )
          }
          onProfile={() => setOverlay({ kind: "profile" })}
        />
      )}
      {screen === "due" && (
        <Due
          month={month}
          onMonthChange={setMonth}
          bills={store.bills}
          name={store.name}
          hidden={hidden}
          onToggleHidden={() => setHidden((h) => !h)}
          onToggle={(bill, paid) => toggleBill(bill.id, paid)}
          onOpenBill={(id) => setOverlay({ kind: "bill", id })}
          onAdd={() => setOverlay({ kind: "add-bill" })}
          onComingUp={() => setOverlay({ kind: "coming-up" })}
          onHistory={() => setOverlay({ kind: "paid-history" })}
          onInstallments={() => go("installments")}
          onProfile={() => setOverlay({ kind: "profile" })}
        />
      )}
      {screen === "installments" && (
        <Installments
          bills={store.bills}
          month={month}
          hidden={hidden}
          onBack={() => go("due")}
          onOpenBill={(id) => setOverlay({ kind: "bill", id })}
          onComingUp={() => setOverlay({ kind: "coming-up" })}
          onHistory={() => setOverlay({ kind: "paid-history" })}
          onAdd={() => setOverlay({ kind: "add-bill" })}
        />
      )}
      {screen === "finance" && (
        <Finance
          name={store.name}
          assets={store.assets}
          moves={store.moves}
          care={store.care}
          worth={store.worth}
          bills={store.bills}
          entries={store.entries}
          birthYear={store.prefs.birthYear}
          hidden={assetsHidden}
          onToggleHidden={() => setAssetsHidden((h) => !h)}
          onAddAsset={store.addAsset}
          addRequest={addAsset}
          onProfile={() => setOverlay({ kind: "profile" })}
          onTalk={() =>
            assistant({
              notice:
                "Talking about family money comes later. For now I record what you spend and receive, and keep track of bills.",
            })
          }
        />
      )}
      {screen === "ai" && (
        <AI
          name={store.name}
          entries={store.entries}
          onOpen={assistant}
          onOpenDay={openDay}
          onProfile={() => setOverlay({ kind: "profile" })}
        />
      )}

      <div className="screen__bottom">
        <TabBar
          active={tab}
          onTab={onTab}
          onPlus={onPlus}
          plusLabel={plusLabel}
          menuOpen={menuOpen}
        />
      </div>
      {menuOpen && (
        <ActionMenu
          onClose={() => setMenuOpen(false)}
          onTalk={() => assistant({})}
          onTemplate={() => {
            setMenuOpen(false);
            setOverlay({ kind: "template" });
          }}
          onScan={() => {
            setMenuOpen(false);
            setOverlay({ kind: "scan" });
          }}
        />
      )}

      {overlay?.kind === "profile" && <Profile store={store} onClose={close} />}
      {overlay?.kind === "scan" && (
        <Suspense fallback={null}>
          <Scan
            banks={store.prefs.banks ?? []}
            onBanks={(banks) => store.setPrefs({ banks })}
            onClose={close}
            onTemplate={(prefill) => setOverlay({ kind: "template", prefill })}
            onWrite={() => setOverlay({ kind: "editor" })}
            onSaveTransfer={(title, amount, note) => {
              const now = Date.now();
              store.addEntries([
                {
                  id: uid(),
                  date: today(),
                  title,
                  amount,
                  flow: "out",
                  category: "Other",
                  noteId: uid(),
                  source: "Scanned a bank QR code",
                  createdAt: now,
                  paidFrom: "Transfer",
                  comment: note,
                },
              ]);
              openDay(today());
            }}
          />
        </Suspense>
      )}
      {overlay?.kind === "template" &&
        (() => {
          const entry = overlay.id
            ? store.entries.find((e) => e.id === overlay.id)
            : undefined;
          if (overlay.id && !entry) return null;
          return (
            <Template
              key={overlay.id ?? "new"}
              entry={entry}
              prefill={overlay.prefill}
              day={range === "day" ? day : today()}
              sources={sources}
              customTags={store.prefs.customTags ?? []}
              onCustomTags={(customTags) => store.setPrefs({ customTags })}
              onClose={close}
              onSave={(e) => {
                if (entry) store.updateEntry(entry.id, e);
                else {
                  store.addEntries([e]);
                  setDay(e.date);
                }
              }}
              onMonthly={(bill, date, amount) => {
                store.addBill(bill);
                store.setBillPaid(bill, ym(date), true, date, amount);
                setDay(date);
              }}
              onDelete={
                entry
                  ? () => {
                      store.removeEntry(entry.id);
                      close();
                    }
                  : undefined
              }
            />
          );
        })()}
      {overlay?.kind === "assistant" && (
        <Assistant
          name={store.name}
          defaultDay={day}
          entries={store.entries}
          bills={store.bills}
          opts={overlay.opts}
          onClose={close}
          onSave={store.addEntries}
          onUndo={store.removeNote}
          onOpenDay={openDay}
        />
      )}
      {overlay?.kind === "editor" && (
        <NoteEditor
          day={day}
          notes={store.notes}
          onClose={close}
          onSave={(date, lines) => {
            store.saveDayNote(date, lines);
            setDay(date);
            setOverlay({ kind: "assistant", opts: { note: { date, lines } } });
          }}
        />
      )}
      {overlay?.kind === "bill" &&
        (() => {
          const bill = store.bills.find((b) => b.id === overlay.id);
          return bill ? (
            <BillSheet
              key={`${bill.id}-${month}`}
              bill={bill}
              month={month}
              onClose={close}
              onCheck={(paid, amount) => toggleBill(bill.id, paid, amount)}
              onDelete={() => {
                store.removeBill(bill.id);
                close();
              }}
            />
          ) : null;
        })()}
      {overlay?.kind === "add-bill" && (
        <AddBill
          month={month}
          onClose={close}
          onSave={(bill) => {
            store.addBill(bill);
            // Stay on this month if the new bill shows up here; otherwise jump to when it starts.
            if (!dueIn(bill, month)) setMonth(ym(bill.start));
            setOverlay(null);
            if (screen !== "installments") go("due");
          }}
        />
      )}
      {overlay?.kind === "coming-up" && (
        <ComingUp
          bills={store.bills}
          month={month}
          onPick={(m) => setMonth(m)}
          onClose={close}
        />
      )}
      {overlay?.kind === "paid-history" && (
        <PaidHistory
          bills={store.bills}
          onClose={close}
          onOpen={(id, m) => {
            setMonth(m);
            setOverlay({ kind: "bill", id });
          }}
        />
      )}
    </div>
  );
}
