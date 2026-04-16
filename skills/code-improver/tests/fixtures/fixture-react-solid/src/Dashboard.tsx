import * as React from "react";

export function Dashboard(): JSX.Element {
  const [data, setData] = React.useState<any>(null);
  const [loading, setLoading] = React.useState(true);
  const [error, setError] = React.useState<string | null>(null);

  React.useEffect(() => {
    fetch("/api/data")
      .then((r) => r.json())
      .then((d) => {
        // business-rule formatting inline
        const formatted = d.items.map((it: any) => ({
          ...it,
          label: it.name.toUpperCase() + " (" + it.count + ")"
        }));
        setData(formatted);
        setLoading(false);
      })
      .catch((e) => {
        setError(String(e));
        setLoading(false);
      });
  }, []);

  if (loading) return <div>loading</div>;
  if (error) return <div>error: {error}</div>;
  return <ul>{data.map((it: any, i: number) => <li key={i}>{it.label}</li>)}</ul>;
}
