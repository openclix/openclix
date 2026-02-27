export interface ConfigDeliveryPattern {
  category: string;
  title: string;
  description: string;
  icon: string;
}

export const configDeliveryPatterns: ConfigDeliveryPattern[] = [
  {
    category: "platform",
    title: "Static JSON Hosting",
    description:
      "Host openclix-config.json on a static web server, CDN, or object storage and fetch it over HTTP.",
    icon: "Smartphone",
  },
  {
    category: "backend",
    title: "Dynamic Config API",
    description:
      "Serve schema-compatible JSON from your backend endpoint to generate campaign config at request time.",
    icon: "Server",
  },
  {
    category: "analytics",
    title: "No-Deploy Campaign Updates",
    description:
      "Update the hosted file or API response to change campaign settings without re-releasing the app.",
    icon: "LineChart",
  },
];
