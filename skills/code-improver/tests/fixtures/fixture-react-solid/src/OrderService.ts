export class OrderService {
  // Mixes DB access, validation, business rules, email, and logging
  async createOrder(input: unknown): Promise<void> {
    this.validate(input);
    const saved = await this.saveToDb(input);
    await this.sendEmail(saved);
    this.logActivity(saved);
  }
  private validate(_input: unknown): void { /* ... */ }
  private async saveToDb(_input: unknown): Promise<unknown> { return {}; }
  private async sendEmail(_saved: unknown): Promise<void> {}
  private logActivity(_saved: unknown): void {}
}
